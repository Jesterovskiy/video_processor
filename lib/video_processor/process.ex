defmodule VideoProcessor.Process do
  use GenServer

  defmodule State do
    defstruct limit: 1, current_count: 0, queue: []
  end

  def start_link do
    IO.puts "Start link"
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    IO.puts "Init"
    {:ok, %State{}}
  end

  def handle_call({:process, params}, _from, state) do
    IO.puts "Get video"
    IO.puts "Start count " <> Integer.to_string(state.current_count)
    {message, new_state} =
      if state.current_count < state.limit do
        IO.puts "Run download"
        Task.async(VideoProcessor.Process, :download, params)
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        IO.puts "Add queue"
        {:added_to_queue, update_in(state.queue, &[params | &1])}
      end
    IO.puts "End count " <> Integer.to_string(new_state.current_count)
    {:reply, message, new_state}
  end

  def handle_cast(:download_finish, state) do
    IO.puts "Download Finish"
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.async(VideoProcessor.Process, :download, params)
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
    GenServer.cast(VideoProcessor.Process, :download_finish)
  end

  # def handle_call(_request, _from, state) do
  #   IO.puts "Handle Call"
  #   new_state =
  #     if state.queue do
  #       Task.async(VideoProcessor, :download, state.queue)
  #       %State{queue: state.queue}
  #     else
  #       %State{current_count: state.current_count - 1}
  #     end
  #   {:noreply, new_state}
  # end
  #
  # def handle_cast(request, state) do
  #   IO.puts "Get video"
  #   IO.puts state.current_count
  #   IO.puts state.queue
  #   new_state =
  #     if state.limit >= state.current_count do
  #       Task.async(VideoProcessor, :download, request)
  #       %State{current_count: state.current_count + 1}
  #     else
  #       %State{queue: request}
  #     end
  #   {:reply, new_state}
  # end

  # def handle_call(request, _from, state) do
  #   IO.puts "Handle Cast"
  #   new_state =
  #     if state.queue do
  #       Task.async(VideoProcessor, :download, state.queue)
  #       %State{queue: state.queue}
  #     else
  #       %State{current_count: state.current_count - 1}
  #     end
  #   {:noreply, new_state}
  # end
end
