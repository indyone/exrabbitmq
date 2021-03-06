defmodule ExRabbitMQ.Consumer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It abstracts the handling of message delivery and acknowlegement.

  It also provides hooks to allow the programmer to wrap the consumption of a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.ConnectionConfig`.

  For a queue configuration example see `ExRabbitMQ.Consumer.ConsumerConfig`.

  #### Example usage for a consumer implementing a `GenServer`

  ```elixir
  defmodule MyExRabbitMQConsumer do
    @module __MODULE__

    use GenServer
    use ExRabbitMQ.Consumer, GenServer

    def start_link() do
      GenServer.start_link(@module, :ok)
    end

    def init(state) do
      new_state =
        xrmq_init(:my_connection_config, :my_consumer_config, state)
        |> xrmq_extract_state()

      {:ok, new_state}
    end

    # required override
    def xrmq_basic_deliver(payload, meta, state) do
      # your message delivery logic goes here...

      {:noreply, state}
    end

    # optional override
    def xrmq_channel_setup(channel, state) do
      # the default channel setup uses the optional qos_opts from
      # the connection's configuration so we can use it
      # automatically by calling super,
      # unless we want to override everything
      {:ok, state} = super(channel, state)

      # any other channel setup goes here...
    end

    # optional override
    def xrmq_queue_setup(channel, queue, state) do
      # the default queue setup uses the optional bind_opts from
      # the queue's configuration so we can use it
      # automatically by calling super,
      # unless we want to override everything
      {:ok, state} = super(channel, queue, state)

      # any other queue setup goes here...
    end
  end
  ```
  """

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  If `start_consuming` is `true` then `c:xrmq_consume/1` is called automatically.

  This variant accepts atoms as the arguments for the `connection_key` and `queue_key` parameters,
  and uses these atoms to read the consumer's configuration.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_init(connection_key :: atom, queue_key :: atom, start_consuming :: true|false, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  If `start_consuming` is `true` then `c:xrmq_consume/1` is called automatically.

  This variant accepts an atom as the argument for the `connection_key` parameter and
  a `ExRabbitMQ.Consumer.ConsumerConfig` struct as the argument for the `consumer_config` parameter.

  The `connection_key` atom argument is used to read the connection's configuration.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_init(connection_key :: atom, consumer_config :: struct, start_consuming :: true|false, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  If `start_consuming` is `true` then `c:xrmq_consume/1` is called automatically.

  This variant accepts a `ExRabbitMQ.Connection` struct as the argument for the `connection_config` parameter and
  an atom as the argument for the `queue_key` parameter.

  The `queue_key` atom argument is used to read the queue's configuration.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_init(connection_config :: struct, queue_key :: atom, start_consuming :: true|false, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  If `start_consuming` is `true` then `c:xrmq_consume/1` is called automatically.

  This variant accepts a `ExRabbitMQ.Connection` and a `ExRabbitMQ.Consumer.ConsumerConfig` structs
  as the arguments for the `connection_config` and `consumer_config` parameters.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_init(connection_config :: struct, consumer_config :: struct, start_consuming :: true|false, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Returns a part of the `:exrabbitmq` configuration section, specified with the
  `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_get_env_config(key :: atom) :: keyword

  @doc """
  Returns the connection configuration as it was passed to `c:xrmq_init/4`.

  This configuration is set in the wrapper process's dictionary.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_get_connection_config() :: term

  @doc """
  Returns the queue configuration as it was passed to `c:xrmq_init/4`.

  This configuration is set in the wrapper process's dictionary.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @callback xrmq_get_consumer_config() :: term

  @doc """
  This hook is called when a connection has been established and a new channel has been opened.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_setup(channel :: term, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This hook is called automatically, if `start_consuming` was `true` when `c:xrmq_init/4`.

  If not, then the user has to call it to start consuming.

  It is invoked when a connection has been established and a new channel has been opened.

  Its flow is to:
  1. Declare the queue
  2. Run `c:xrmq_queue_setup/3`
  3. Start consuming from the queue

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_consume(state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This hook is called automatically as part of the flow in `c:xrmq_consume/1`.

  It allows the user to run extra queue setup steps when the queue has been declared.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_queue_setup(channel :: term, queue :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This callback is the only required callback (i.e., without any default implementation) and
  is called as a response to a `:basic_consume` message.

  It is passed the `payload` of the request as well as the `meta` object or the message.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_deliver(payload :: term, meta :: term, state :: term) ::
    {:noreply, new_state :: term} |
    {:noreply, new_state :: term, timeout | :hibernate} |
    {:noreply, [event :: term], new_state :: term} |
    {:noreply, [event :: term], new_state :: term, :hibernate} |
    {:stop, reason :: term, new_state :: term}

  @doc """
  This overridable hook is  called as a response to a `:basic_cancel` message.

  It is passed the `cancellation_info` of the request and by default it logs an error and
  returns `{:stop, :basic_cancel, state}`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_cancel(cancellation_info :: any, state :: any) ::
    {:noreply, new_state :: term} |
    {:noreply, new_state :: term, timeout | :hibernate} |
    {:noreply, [event :: term], new_state :: term} |
    {:noreply, [event :: term], new_state :: term, :hibernate} |
    {:stop, reason :: term, new_state :: term}

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user
  wants to *ack* a message.

  It is passed the `delivery_tag` of the request and by default it simply *acks* the message
  as per the RabbitMQ API.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_ack(delivery_tag :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user wants
  to reject a message.

  It is passed the `delivery_tag` of the request and by default it simply rejects the message
  as per the RabbitMQ API.

  This function simply calls `c:xrmq_basic_reject/3` with `opts` set to `[]`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_reject(delivery_tag :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user wants
  to reject a message.

  It is passed the `delivery_tag` of the request and by default it simply rejects the message
  as per the RabbitMQ API.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_reject(delivery_tag :: String.t, opts :: term, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This overridable function publishes the `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(payload :: term, exchange :: String.t, routing_key :: String.t, opts :: [term]) ::
  :ok |
  {:error, reason :: :blocked | :closing | :no_channel}

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, state :: term}|{:error, reason :: term, state :: term}) ::
    state :: term

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Consumer.GenServer
  require ExRabbitMQ.AST.Consumer.GenStage

  defmacro __using__({:__aliases__, _, [kind]})
  when kind in [:GenServer, :GenStage] do
    common_ast = ExRabbitMQ.AST.Common.ast()

    inner_ast =
      if kind === :GenServer do
        ExRabbitMQ.AST.Consumer.GenServer.ast()
      else
        ExRabbitMQ.AST.Consumer.GenStage.ast()
      end

    quote location: :keep do
      require Logger

      @behaviour ExRabbitMQ.Consumer

      alias ExRabbitMQ.Constants
      alias ExRabbitMQ.Connection
      alias ExRabbitMQ.ConnectionConfig
      alias ExRabbitMQ.Consumer.ConsumerConfig

      unquote(inner_ast)

      def xrmq_init(connection_config_spec, consumer_config_spec, start_consuming \\ true, state)

      def xrmq_init(connection_key, queue_key, start_consuming, state)
      when is_atom(connection_key) and is_atom(queue_key) do
        xrmq_init(xrmq_get_connection_config(connection_key), xrmq_get_consumer_config(queue_key),
          start_consuming, state)
      end

      def xrmq_init(connection_key, %ConsumerConfig{} = consumer_config, start_consuming, state)
      when is_atom(connection_key) do
        xrmq_init(xrmq_get_connection_config(connection_key), consumer_config, start_consuming, state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, queue_key, start_consuming, state)
      when is_atom(queue_key) do
        xrmq_init(connection_config, xrmq_get_consumer_config(queue_key), start_consuming, state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, %ConsumerConfig{} = consumer_config,
        start_consuming, state) do
        connection_config = xrmq_set_connection_config_defaults(connection_config)
        consumer_config = xrmq_set_consumer_config_defaults(consumer_config)

        connection_pids_group_name = Constants.connection_pids_group_name()

        connection_pids =
          case :pg2.get_local_members(connection_pids_group_name) do
            [] -> []
            [_pid | _rest_pids] = pids -> pids
            {:error, {:no_such_group, ^connection_pids_group_name}} -> []
          end

        connection_pid =
          case Enum.find(connection_pids, fn c -> Connection.subscribe(c, connection_config) end) do
            nil ->
              {:ok, pid} = ExRabbitMQ.ConnectionSupervisor.start_child(connection_config)
              Connection.subscribe(pid, connection_config)
              pid
            pid ->
              pid
          end

        Process.link(connection_pid)

        xrmq_set_connection_pid(connection_pid)
        xrmq_set_connection_config(connection_config)
        xrmq_set_consumer_config(consumer_config)

        if start_consuming do
          xrmq_open_channel_consume(state)
        else
          xrmq_open_channel(state)
        end
      end

      def xrmq_consume(state) do
        {{channel, _}, config} = {xrmq_get_channel_info(), xrmq_get_consumer_config()}

        if channel === nil or config === nil do
          nil
        else
          with \
            {:ok, %{queue: queue}} <- AMQP.Queue.declare(channel, config.queue, config.queue_opts),
            {:ok, new_state} <- xrmq_queue_setup(channel, queue, state),
            {:ok, _} <- AMQP.Basic.consume(channel, queue, nil, config.consume_opts)
          do
            {:ok, new_state}
          else
            {:error, reason, state} = error -> error
            {:error, reason} -> {:error, reason, state}
            error -> {:error, error, state}
          end
        end
      end

      defp xrmq_set_consumer_config_defaults(%ConsumerConfig{} = config) do
        %ConsumerConfig{
          queue: config.queue || "",
          queue_opts: config.queue_opts || [],
          consume_opts: config.consume_opts || [],
          bind_opts: config.bind_opts || nil,
          qos_opts: config.qos_opts || nil,
        }
      end

      def xrmq_channel_setup(channel, state) do
        with \
          %{qos_opts: opts} when opts != nil <- xrmq_get_consumer_config(),
          :ok <- AMQP.Basic.qos(channel, opts)
        do
          {:ok, state}
        else
          %{qos_opts: nil} -> {:ok, state}
          {:error, reason} -> {:error, reason, state}
        end
      end

      def xrmq_queue_setup(channel, queue, state) do
        with \
          %{bind_opts: opts} when opts != nil <- xrmq_get_consumer_config(),
          :ok <- AMQP.Queue.bind(channel, queue, opts[:exchange], opts[:extra_opts] || [])
        do
          {:ok, state}
        else
          %{bind_opts: nil} -> {:ok, state}
          {:error, reason} -> {:error, reason, state}
        end
      end

      def xrmq_basic_ack(delivery_tag, state) do
        case xrmq_get_channel_info() do
          {nil, _} ->
            {:error, Constants.no_channel_error(), state}
          {channel, _} ->
            try do
              case AMQP.Basic.ack(channel, delivery_tag) do
                :ok -> {:ok, state}
                error -> {:error, error, state}
              end
            catch
              :exit, reason ->
                {:error, reason, state}
            end
        end
      end

      def xrmq_basic_reject(delivery_tag, state) do
        xrmq_basic_reject(delivery_tag, [], state)
      end

      def xrmq_basic_reject(delivery_tag, opts, state) do
        case xrmq_get_channel_info() do
          {nil, _} ->
            {:error, Constants.no_channel_error(), state}
          {channel, _} ->
            try do
              case AMQP.Basic.reject(channel, delivery_tag, opts) do
                :ok -> {:ok, state}
                error -> {:error, error, state}
              end
            catch
              :exit, reason ->
                {:error, reason, state}
            end
        end
      end

      def xrmq_get_consumer_config() do
        Process.get(Constants.consumer_config_key())
      end

      defp xrmq_get_consumer_config(key) do
        config = xrmq_get_env_config(key)

        %ConsumerConfig{
          queue: config[:queue],
          queue_opts: config[:queue_opts],
          consume_opts: config[:consume_opts],
          bind_opts: config[:bind_opts],
          qos_opts: config[:qos_opts],
        }
      end

      defp xrmq_set_consumer_config(config) do
        if config === nil do
          Process.delete(Constants.consumer_config_key())
        else
          Process.put(Constants.consumer_config_key(), config)
        end
      end

      defp xrmq_open_channel_consume(state) do
        with\
          {:ok, new_state} <- xrmq_open_channel(state),
          {:ok, new_state} = result_ok <- xrmq_consume(new_state) do
          result_ok
        else
          error -> error
        end
      end

      unquote(common_ast)

      defoverridable xrmq_queue_setup: 3, xrmq_basic_cancel: 2, xrmq_basic_ack: 2, xrmq_basic_reject: 2, xrmq_basic_reject: 3
    end
  end
end
