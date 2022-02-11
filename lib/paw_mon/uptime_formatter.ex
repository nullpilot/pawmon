defmodule PawMon.UptimeFormatter do
  @moduledoc """
  Handles formatting timestamps in abbreviated form.

  This formatter is based on the source of [`Timex.Format.Duration.Fotmatters.Humanized`](https://github.com/bitwalker/timex/blob/main/lib/format/duration/formatters/humanized.ex).
  """
  use Timex.Format.Duration.Formatter
  alias Timex.Translator

  @minute 60
  @hour @minute * 60
  @day @hour * 24
  @month @day * 30
  @year @day * 365

  @microsecond 1_000_000

  @doc """
  Return a human readable string representing the absolute value of duration (i.e. would
  return the same output for both negative and positive representations of a given duration)
  ## Examples
      iex> use Timex
      ...> Duration.from_erl({0, 1, 1_000_000}) |> #{__MODULE__}.format
      "2s"
      iex> use Timex
      ...> Duration.from_erl({0, 1, 1_000_100}) |> #{__MODULE__}.format
      "2 seconds, 100 microseconds"
      iex> use Timex
      ...> Duration.from_erl({0, 65, 0}) |> #{__MODULE__}.format
      "1 minute, 5 seconds"
      iex> use Timex
      ...> Duration.from_erl({0, -65, 0}) |> #{__MODULE__}.format
      "1 minute, 5 seconds"
      iex> use Timex
      ...> Duration.from_erl({1435, 180354, 590264}) |> #{__MODULE__}.format
      "45 years, 6 months, 5 days, 21 hours, 12 minutes, 34 seconds, 590.264 milliseconds"
  """
  @spec format(Duration.t()) :: String.t() | {:error, term}
  def format(%Duration{} = duration), do: lformat(duration, Translator.current_locale())
  def format(_), do: {:error, :invalid_duration}

  @doc """
  Return a human readable string representing the time interval, translated to the given locale
  ## Examples
      iex> use Timex
      ...> Duration.from_erl({0, 65, 0}) |> #{__MODULE__}.lformat("ru")
      "1 минута, 5 секунд"
      iex> use Timex
      ...> Duration.from_erl({1435, 180354, 590264}) |> #{__MODULE__}.lformat("ru")
      "45 лет, 6 месяцев, 5 дней, 21 час, 12 минут, 34 секунды, 590.264 миллисекунд"
  """
  @spec lformat(Duration.t(), String.t()) :: String.t() | {:error, term}
  def lformat(%Duration{} = duration, locale) do
    duration
    |> deconstruct
    |> do_format(locale)
  end

  def lformat(_, _locale), do: {:error, :invalid_duration}

  defp do_format(components, locale),
    do: do_format(components, <<>>, locale)

  defp do_format([], str, _locale),
    do: str

  defp do_format([{unit, value} | rest], str, locale) do
    unit = Atom.to_string(unit)

    unit_with_value = "#{value}#{abbr(unit)}"

    case str do
      <<>> -> do_format(rest, "#{unit_with_value}", locale)
      _ -> do_format(rest, str <> " #{unit_with_value}", locale)
    end
  end

  defp deconstruct(duration) do
    micros = Duration.to_microseconds(duration) |> abs
    deconstruct({div(micros, @microsecond), rem(micros, @microsecond)}, [])
  end

  defp deconstruct({0, 0}, []),
    do: deconstruct({0, 0}, microsecond: 0)

  defp deconstruct({0, 0}, components),
    do: Enum.reverse(components)

  defp deconstruct({seconds, us}, components) when seconds > 0 do
    cond do
      seconds >= @year ->
        deconstruct({rem(seconds, @year), us}, [{:year, div(seconds, @year)} | components])

      seconds >= @month ->
        deconstruct({rem(seconds, @month), us}, [{:month, div(seconds, @month)} | components])

      seconds >= @day ->
        deconstruct({rem(seconds, @day), us}, [{:day, div(seconds, @day)} | components])

      seconds >= @hour ->
        deconstruct({rem(seconds, @hour), us}, [{:hour, div(seconds, @hour)} | components])

      seconds >= @minute ->
        deconstruct({rem(seconds, @minute), us}, [{:minute, div(seconds, @minute)} | components])

      true ->
        deconstruct({0, us}, [{:second, seconds} | components])
    end
  end

  defp deconstruct({0, micro}, components) do
    millis =
      micro
      |> Duration.from_microseconds()
      |> Duration.to_milliseconds()

    cond do
      millis >= 1 -> deconstruct({0, 0}, [{:millisecond, millis} | components])
      true -> deconstruct({0, 0}, [{:microsecond, micro} | components])
    end
  end

  defp abbr("millisecond"), do: "ms"
  defp abbr("second"), do: "s"
  defp abbr("minute"), do: "m"
  defp abbr("hour"), do: "h"
  defp abbr("day"), do: "D"
  defp abbr("month"), do: "M"
  defp abbr("year"), do: "Y"
  defp abbr(_), do: ""
end
