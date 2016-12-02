defmodule VideoProcessor.Periodically do
  use GenServer

  def start_link do
    IO.puts "Periodically start"
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    IO.puts "Init"
    Process.send(self(), :work, [])
    {:ok, state}
  end

  def handle_info(:work, state) do
    IO.puts "Handle info"
    body = HTTPoison.get!(Application.get_env(:video_processor, :url)).body
    Enum.each(Floki.find(body, "item") |> Enum.slice(0, 2),
      # Floki.find(body, "item"),
      fn(x) ->
        url = parse_xml(x, "link")
        filename = parse_xml(x, "guid") <> ".mp4"
        GenServer.call(VideoProcessor.Download, {:process, [url, filename]})
      end
    )
    schedule_work() # Reschedule once more
    {:noreply, state}
  end

  defp schedule_work() do
    IO.puts "Schedule Work"
    Process.send_after(self(), :work, 300 * 60 * 1000) # In 2 hours
  end

  defp parse_xml(item, element) do
    Floki.find(item, element) |> List.first |> elem(2) |> List.first
  end
end
