defmodule ExRabbitMQ.Connection do
  @moduledoc """
  A GenServer implementing a long running connection to a RabbitMQ server, with embedded PubSub using :pg2 and :ets.
  """

  use GenServer

  require Logger

  alias ExRabbitMQ.Connection
  alias ExRabbitMQ.ConnectionConfig
  alias ExRabbitMQ.Constants

  defstruct [:connection, :connection_pid, :ets_consumers, config: %ConnectionConfig{}, stale?: false]

  @doc false
  def start_link(%ConnectionConfig{} = config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc false
  def init(config) do
    Process.flag(:trap_exit, true)

    :ok = :pg2.create(Constants.connection_pids_group_name)
    :ok = :pg2.join(Constants.connection_pids_group_name, self())

    ets_consumers = Constants.connection_pids_group_name |> String.to_atom() |> :ets.new([:private])

    Process.send(self(), :connect, [])

    schedule_cleanup()

    {:ok, %Connection{config: config, ets_consumers: ets_consumers}}
  end

  @doc """
  Checks whether this process holds a usable connection to RabbitMQ.

  `connection_pid` is the GenServer pid implementing the called `ExRabbitMQ.Connection`)
  """
  @spec get(pid) :: true | false | {:error, any}
  def get(connection_pid) do
    case connection_pid do
      nil ->
        {:error, :nil_connection_pid}
      connection_pid ->
        try do
          GenServer.call(connection_pid, :get)
        catch
          :exit, reason ->
            {:error, reason}
        end
    end
  end

  @doc """
  Subscribes a consumer process, via `self()`, to the managed ETS table.

  If the ETS table already contains 65535 consumers, and thus the maximum allowed 65535 channels, then the subscription
  is not allowed so that a new connection can be created.

  `connection_pid` is the GenServer pid implementing the called `ExRabbitMQ.Connection`)
  """
  @spec subscribe(pid) :: true | false
  def subscribe(connection_pid) do
    GenServer.call(connection_pid, {:subscribe, self()})
  end

  @doc """
  Gracefully closes the RabbitMQ connection and terminates its GenServer handler identified by `connection_pid`.
  """
  @spec close(pid) :: :ok
  def close(connection_pid) do
    GenServer.cast(connection_pid, :close)
  end

  @doc false
  def handle_call(:get, _from, %Connection{connection: connection} = state) do
    reply = if connection === nil, do: {:error, :nil_connection_pid}, else: {:ok, connection}
    {:reply, reply, state}
  end

  @doc false
  def handle_call({:subscribe, consumer_pid}, _from, %Connection{ets_consumers: ets_consumers} = state) do
    result =
      case :ets.info(ets_consumers)[:size] do
        65_535 ->
          false
        _ ->
          :ets.insert_new(ets_consumers, {consumer_pid})
          Process.monitor(consumer_pid)
          true
      end

    new_state = %{state | stale?: false}

    {:reply, result, new_state}
  end

  @doc false
  def handle_cast(:close, %Connection{
    ets_consumers: ets_consumers,
    connection: connection,
    connection_pid: connection_pid} = state) do
    if connection === nil do
      {:stop, :normal, state}
    else
      Process.unlink(connection_pid)

      AMQP.Connection.close(connection)

      publish(ets_consumers, {:xrmq_connection, {:closed, nil}})

      new_state = %{state | connection: nil, connection_pid: nil}

      {:stop, :normal, new_state}
    end
  end

  @doc false
  def handle_info(:connect, %Connection{config: config, ets_consumers: ets_consumers} = state) do
    Logger.debug("connecting to RabbitMQ")

    case AMQP.Connection.open(
      username: config.username,
      password: config.password,
      host: config.host,
      port: config.port,
      virtual_host: config.vhost,
      heartbeat: config.heartbeat) do
        {:ok, %AMQP.Connection{pid: connection_pid} = connection} ->
          Logger.debug("connected to RabbitMQ")

          Process.link(connection_pid)

          publish(ets_consumers, {:xrmq_connection, {:open, connection}})

          new_state = %{state | connection: connection, connection_pid: connection_pid}

          {:noreply, new_state}
        {:error, reason} ->
          Logger.error("failed to connect to RabbitMQ: #{inspect(reason)}")

          Process.send_after(self(), :connect, config.reconnect_after)

          new_state = %{state | connection: nil, connection_pid: nil}

          {:noreply, new_state}
      end
  end

  @doc false
  def handle_info({:EXIT, pid, _reason},
    %Connection{config: config, connection_pid: connection_pid, ets_consumers: ets_consumers} = state)
  when pid === connection_pid do
    publish(ets_consumers, {:xrmq_connection, {:closed, nil}})

    Logger.error("disconnected from RabbitMQ")

    Process.send_after(self(), :connect, config.reconnect_after)

    new_state = %{state | connection: nil, connection_pid: nil}

    {:noreply, new_state}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, consumer_pid, _reason}, %Connection{ets_consumers: ets_consumers} = state) do
    :ets.delete(ets_consumers, consumer_pid)

    {:noreply, state}
  end

  @doc false
  def handle_info(:cleanup, %{ets_consumers: ets_consumers, stale?: stale?} = state) do
    if stale? do
      {:stop, :normal, state}
    else
      new_state =
        case :ets.info(ets_consumers)[:size] do
          0 -> %{state | stale?: true}
          _ -> state
        end

      schedule_cleanup()

      {:noreply, new_state}
    end
  end

  @doc false
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp publish(ets_consumers, what) do
    ets_consumers
    |> :ets.select([{:"_", [], [:"$_"]}])
    |> Enum.split_with(fn {consumer_pid} ->
      if Process.alive?(consumer_pid) do
        send(consumer_pid, what)
      else
        :ets.delete(ets_consumers, consumer_pid)
      end
    end)
  end

  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, 5000)
  end
end