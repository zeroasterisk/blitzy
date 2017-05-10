defmodule Blitzy do
  use Application
  require Logger

  def start(_type, _args) do
    Blitzy.Supervisor.start_link(:ok)
  end

  def do_requests(n_requests, url, nodes) do
    me = self()
    IO.puts "Pummelling #{url} with #{n_requests} requests from #{inspect me}"
    Logger.info "Pummelling #{url} with #{n_requests} requests from #{inspect me}"

    total_nodes  = Enum.count(nodes)
    req_per_node = div(n_requests, total_nodes)

    nodes
    |> Enum.flat_map(fn node ->
         1..req_per_node |> Enum.map(fn _ ->
           Task.Supervisor.async(
            {TasksSupervisor, node},
            Blitzy.Worker,
            :start,
            [url, me]
          )
         end)
       end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> parse_results
  end


  # def run(n_workers, url) when n_workers > 0 do
  #   worker_fun = fn -> Blitzy.Worker.start(url) end
  #   1..n_workers
  #   |> Enum.map(fn _ -> Task.async(worker_fun) end)
  #   |> Enum.map(&Task.await(&1, :infinity))
  # end

  def parse_results(results) do
    {successes, _failures} =
      results
        |> Enum.partition(fn x ->
             case x do
               {:ok, _} -> true
               _        -> false
           end
         end)

    total_workers = Enum.count(results)
    total_success = Enum.count(successes)
    total_failure = total_workers - total_success

    data = successes |> Enum.map(fn {:ok, time} -> time end)
    average_time  = average(data)
    longest_time  = Enum.max(data)
    shortest_time = Enum.min(data)

    IO.puts """
    Total workers    : #{total_workers}
    Successful reqs  : #{total_success}
    Failed reqs      : #{total_failure}
    Average (msecs)  : #{average_time}
    Longest (msecs)  : #{longest_time}
    Shortest (msecs) : #{shortest_time}
    """
  end

  defp average(list) do
    sum = Enum.sum(list)
    if sum > 0 do
      sum / Enum.count(list)
    else
      0
    end
  end


end
