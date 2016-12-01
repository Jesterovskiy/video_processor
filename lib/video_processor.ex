defmodule VideoProcessor do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    IO.puts "App Start"
    children = [
      worker(VideoProcessor.Periodically, []),
      worker(VideoProcessor.Download, []),
      worker(VideoProcessor.S3Upload, [])
    ]

    opts = [strategy: :one_for_one, name: VideoProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
