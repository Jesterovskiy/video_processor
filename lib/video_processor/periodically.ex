defmodule VideoProcessor.Periodically do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    Process.send(self(), :work, [])
    {:ok, state}
  end

  def handle_info(:work, state) do
    IO.puts inspect Confex.get(:video_processor, :complex_feed_url)
    IO.puts inspect Application.get_env(:video_processor, :complex_feed_url)
    response = Confex.get(:video_processor, :complex_feed_url) |> HTTPoison.get!
    Enum.each(Floki.find(response.body, "item") |> Enum.slice(0, 1),
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
