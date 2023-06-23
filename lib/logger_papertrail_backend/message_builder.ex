defmodule LoggerPapertrailBackend.MessageBuilder do
  @moduledoc """
    Handles building messages that will be sent to Papertrail from Elixir
  """
  @doc """
  Will build a syslog-message, roughly conforming to a BSD syslogmessage, RFC 3164.
  But it is specially fitted to work with PaperTrail, http://papertrailapp.com

  ## Example

      iex> LoggerPapertrailBackend.MessageBuilder.build("Hello PaperTrail!", :error, "my_system_name", {{2015,10,1}, {12,44,1}}, "Elixir.Hello.World")
      "<11>Oct  1 12:44:01 my_system_name Hello.World Hello PaperTrail!"
  """

  @spec build(
          message :: binary,
          level :: atom,
          hostname :: binary,
          timestamp :: tuple,
          tag :: any
        ) :: binary
  def build(message, level, hostname, timestamp, tag) do
    # Papertrail does not care it seems, so just use :user
    facility = :user
    priority = calculate_priority(facility, level)
    bsd_timestamp = create_bsd_timestamp(timestamp)
    trimmed_tag = trim_tag(tag)
    "<#{priority}>#{bsd_timestamp} #{hostname} #{trimmed_tag} #{message}"
  end

  defp create_bsd_timestamp({date, {h, m, s, _ms}}), do: create_bsd_timestamp({date, {h, m, s}})

  defp create_bsd_timestamp({{_y, mo, d}, {h, m, s}}) do
    months = ~W{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec}
    padded_day = d |> Integer.to_string() |> String.pad_leading(2)
    month = months |> Enum.at(mo - 1)
    zeropad = fn i -> i |> Integer.to_string() |> String.pad_leading(2, "0") end
    "#{month} #{padded_day} #{zeropad.(h)}:#{zeropad.(m)}:#{zeropad.(s)}"
  end

  defp trim_tag(tag) when is_binary(tag) do
    stripped = tag |> String.trim() |> String.replace("Elixir.", "")
    trim_tag(stripped, String.length(stripped))
  end

  defp trim_tag(tag), do: trim_tag("#{tag}")

  defp trim_tag(tag, current_length) when current_length <= 32, do: tag

  defp trim_tag(tag, _) do
    modules = tag |> String.split(".")
    new_tag = trim_module_name(modules) |> Enum.join(".")
    trim_tag(new_tag, String.length(new_tag))
  end

  defp trim_module_name(modules), do: trim_module_name(modules, [])
  defp trim_module_name([], state), do: Enum.reverse(state)

  defp trim_module_name([last_single_module | []], []),
    do: [String.slice(last_single_module, 0, 32)]

  defp trim_module_name([_head | tail], state), do: (state |> Enum.reverse()) ++ tail

  # https://tools.ietf.org/html/rfc3164#section-4.1.1

  defp calculate_priority(facility, level), do: facility(facility) * 8 + level(level)

  # Thanks to https://github.com/jkvor/erlang_syslog/blob/master/src/syslog.erl

  # map elixir :warn to :warning
  defp level(:warn), do: level(:warning)
  # system is unusable
  defp level(:emergency), do: 0
  # action must be taken immediately
  defp level(:alert), do: 1
  # critical conditions
  defp level(:critical), do: 2
  # error conditions
  defp level(:error), do: 3
  # warning conditions
  defp level(:warning), do: 4
  # normal but significant condition
  defp level(:notice), do: 5
  # informational
  defp level(:info), do: 6
  # debug-level messages
  defp level(:debug), do: 7
  # default to info
  defp level(_), do: level(:info)

  # % paraphrased from https://github.com/ngerakines/syslognif/blob/master/src/syslog.erl#L55
  # kernel messages
  defp facility(:kern), do: 0
  # random user-level messages
  defp facility(:user), do: 1
  # mail system
  defp facility(:mail), do: 2
  # system daemons
  defp facility(:daemon), do: 3
  # security/authorization messages
  defp facility(:auth), do: 4
  # messages generated internally by syslogd
  defp facility(:syslog), do: 5
  # line printer subsystem
  defp facility(:lpr), do: 6
  # network news subsystem
  defp facility(:news), do: 7
  # UUCP subsystem
  defp facility(:uucp), do: 8
  # clock daemon
  defp facility(:cron), do: 9
  # security/authorization messages (private)
  defp facility(:authpriv), do: 10
  # ftp daemon
  defp facility(:ftp), do: 11

  # reserved for local use
  defp facility(:local0), do: 16
  # reserved for local use
  defp facility(:local1), do: 17
  # reserved for local use
  defp facility(:local2), do: 18
  # reserved for local use
  defp facility(:local3), do: 19
  # reserved for local use
  defp facility(:local4), do: 20
  # reserved for local use
  defp facility(:local5), do: 21
  # reserved for local use
  defp facility(:local6), do: 22
  # reserved for local use
  defp facility(:local7), do: 23
  defp facility(_), do: facility(:user)
end
