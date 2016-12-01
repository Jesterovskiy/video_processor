defmodule VideoProcessor.S3Upload do
  use GenServer

  defmodule State do
    defstruct limit: 1, current_count: 0, queue: []
  end

  def start_link do
    IO.puts "Start S3Upload"
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    IO.puts "Init"
    {:ok, %State{}}
  end

  def handle_call({:process, source_file}, _from, state) do
    IO.puts "Upload Video to S3"
    IO.puts "Start count " <> Integer.to_string(state.current_count)
    {message, new_state} =
      if state.current_count < state.limit do
        IO.puts "Run upload"
        Task.async(VideoProcessor.S3Upload, :s3_upload, [source_file])
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        IO.puts "Add queue"
        {:added_to_queue, update_in(state.queue, &[source_file | &1])}
      end
    IO.puts "End count " <> Integer.to_string(new_state.current_count)
    {:reply, message, new_state}
  end

  def handle_cast(:s3_upload_finish, state) do
    IO.puts "S3 Upload Finish"
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.async(VideoProcessor.S3Upload, :s3_upload, [params])
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def s3_upload(source_file) do
    IO.puts "Uploading #{source_file} to S3 test/#{source_file}"
    source_file = File.read!(source_file)
    ExAws.S3.put_object(Application.get_env(:ex_aws, :upload_bucket), "testvideo", source_file) |> ExAws.request!
    IO.puts "Done Uploading #{source_file} to S3"
    GenServer.cast(VideoProcessor.S3Upload, :s3_upload_finish)
  end
end
