defmodule VideoProcessor.Download do
  use GenServer

  defmodule State do
    defstruct limit: 1, current_count: 0, queue: []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    {:ok, %State{}}
  end

  def handle_call({:process, params}, _from, state) do
    {message, new_state} =
      if state.current_count < state.limit do
        Task.async(VideoProcessor.Download, :download, params)
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        {:added_to_queue, update_in(state.queue, &[params | &1])}
      end
    {:reply, message, new_state}
  end

  def handle_cast({:download_finish, filename}, state) do
    GenServer.call(VideoProcessor.S3Upload, {:process, filename})
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.async(VideoProcessor.Download, :download, params)
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def download(src, output_filename) do
    IO.puts "Downloading #{src} -> #{output_filename}"
    body = HTTPoison.get!(src).body
    File.write!(output_filename, body)
    IO.puts "Done Downloading #{src} -> #{output_filename}"
    GenServer.cast(VideoProcessor.Download, {:download_finish, output_filename})
  end
end
