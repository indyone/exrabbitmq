defmodule ExRabbitMQ.Constants do
  @moduledoc """
  A module holding constants (e.g., process dictionay keys) that are used in multiple sites.
  """

  @doc """
  The [`:pg2`](http://erlang.org/doc/man/pg2.html) group name for the connections to RabbitMQ
  """
  def connection_pids_group_name(), do: "ExRabbitMQConnections"

  @doc """
  The key in the process dictionary holding the connection pid (GenServer) used by a consumer or a producer.
  """
  def connection_pid_key(), do: :xrmq_connection_pid

  @doc """
  The key in the process dictionary holding the connection configuration used by consumers and producers.
  """
  def connection_config_key(), do: :xrmq_connection_config

  @doc """
  The key in the process dictionary holding the queue configuration used by a consumer.
  """
  def consumer_config_key(), do: :xrmq_consumer_config

  @doc """
  The key in the process dictionary holding the channel struct used by a consumer or a producer.
  """
  def channel_key(), do: :xrmq_channel

  @doc """
  The key in the process dictionary holding the channel monitor reference for the open channel used by a consumer or a producer.
  """
  def channel_monitor_key(), do: :xrmq_channel_monitor

  @doc """
  The error returned when an attempt to use a closed channel is made.
  """
  def no_channel_error(), do: :no_channel
end
