defmodule VideoProcessor.Download do
  use GenServer

  defmodule State do
    defstruct limit: Confex.get(:video_processor, :task_limit), current_count: 0, queue: []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    {:ok, %State{}}
  end

  def handle_call({:process, complex_media}, _from, state) do
    {message, new_state} =
      if state.current_count < state.limit do
        Task.start(VideoProcessor.Download, :download, [complex_media])
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        {:added_to_queue, update_in(state.queue, &[complex_media | &1])}
      end
    {:reply, message, new_state}
  end

  def handle_cast({:download_finish, complex_media}, state) do
    filename = parse_xml(complex_media, "guid") <> ".mp4"
    :dets.open_file(Confex.get(:video_processor, :disk_storage), [type: :set])
    :dets.insert(Confex.get(:video_processor, :disk_storage), {filename, "download_finish"})
    :dets.close(Confex.get(:video_processor, :disk_storage))
    # GenServer.call(VideoProcessor.S3Upload, {:process, complex_media})
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.start(VideoProcessor.Download, :download, [params])
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def download(complex_media) do
    url      = parse_xml(complex_media, "link")
    filename = parse_xml(complex_media, "guid") <> ".mp4"
    download_dir = Confex.get(:video_processor, :download_dir)
    IO.puts "Downloading #{url} -> #{download_dir <> filename}"
    # {:ok, status, headers, client} = :hackney.request(url)
    # {:ok, body} = :hackney.body(client)
    # File.write!(download_dir <> "/" <> filename, body)
    File.write!(download_dir <> "/" <> filename, HTTPoison.get!(url).body)
    IO.puts "Done Downloading #{url} -> #{download_dir <> filename}"
    GenServer.cast(VideoProcessor.Download, {:download_finish, complex_media})
  end

  defp parse_xml(item, element) do
    Floki.find(item, element) |> List.first |> elem(2) |> List.first
  end
end
