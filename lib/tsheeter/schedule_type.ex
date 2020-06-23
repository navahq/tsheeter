defmodule Tsheeter.ScheduleType do
  use Ecto.Type
  def type, do: :map
  alias Tsheeter.ScheduleType

  defstruct sunday: false,
            monday: true,
            tuesday: true,
            wednesday: true,
            thursday: true,
            friday: true,
            saturday: false,
            hour: 16,
            minute: 30

  def default_saved_schedule(), do: %ScheduleType{}

  def default_submitted_schedule() do
    Map.merge(
      default_saved_schedule(),
      %{monday: false, tuesday: false, wednesday: false, thursday: false}
    )
  end

  def cast(%ScheduleType{} = schedule) do
    {:ok, schedule}
  end

  def cast(_), do: :error

  def load(data) when is_map(data) do
    data = for {key, val} <- data, do: {to_atom(key), val}
    {:ok, struct!(ScheduleType, data)}
  end

  def dump(%ScheduleType{} = s), do: {:ok, Map.from_struct(s)}
  def dump(_), do: :error

  defp to_atom(x) when is_atom(x), do: x
  defp to_atom(x) when is_binary(x), do: String.to_existing_atom(x)
end
