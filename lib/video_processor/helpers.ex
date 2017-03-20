defmodule VideoProcessor.Helpers do
  def parse_xml_item(item, element) do
    result = Floki.find(item, element)
    if result |> Enum.empty?, do: "", else: result |> List.first |> elem(2) |> List.first
  end
end
