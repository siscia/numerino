defmodule Mix.Tasks.Test.Numerino do
  use Mix.Task

  @shortdoc "test the performance of Numerino"

  def run(args) do
    HTTPoison.start
    Numerino.Tester.Collector.start_link

    {switch, _, _} = OptionParser.parse(args, strict: [processes: :integer, duration: :integer, url: :string])

    processes = Keyword.get(switch, :processes, 30)
    duration  = Keyword.get(switch, :duration,  30)
    url       = Keyword.get(switch, :url, "http://localhost:4000")

    for _ <- 1..processes do 
      pid = spawn(fn -> first_run url end)
      :timer.kill_after((duration + 1) * 1000, pid)
    end
    :timer.sleep((duration + 5) * 1000)
    Mix.Shell.IO.info("\n\n\tCorrectness analysis: \n")
    correctness_analysis
    Mix.Shell.IO.info("\n\n\tPerformance analysis: \n")
    performance_analysis
    Mix.Shell.IO.info("\n\n")
  end

  defp correctness_analysis do
    analytics = Numerino.Tester.Analyzer.load_info 
              |> Numerino.Tester.Analyzer.partition_by_queue 
              |> Numerino.Tester.Analyzer.order_partition
    result = Numerino.Tester.Analyzer.check_correctness analytics
    correct = Enum.filter(result, fn {_, {bool, _}} -> bool == true end)
    wrong = Enum.filter(result, fn {_, {bool, _}} -> bool == false end)
    Mix.Shell.IO.info "\t\tQueue created:  \t\t #{length(result)}"
    Mix.Shell.IO.info "\t\tCorrect queues: \t\t #{length(correct)}"
    Mix.Shell.IO.info "\t\tWrong queues:   \t\t #{length(wrong)}"
  end

  defp performance_analysis do
    analytics = Numerino.Tester.Analyzer.load_info
              |> Numerino.Tester.Analyzer.order_by_duration
    total_request = Numerino.Tester.Analyzer.total_rounds analytics
    start_time = Numerino.Tester.Analyzer.first_request_time analytics
    end_time = Numerino.Tester.Analyzer.last_response_time analytics
    total_time = :erlang.convert_time_unit(end_time - start_time, :native, :milli_seconds)
    Mix.Shell.IO.info "\tTotal requests: #{total_request}"
    Mix.Shell.IO.info "\tTotal time: #{total_time} msec"
    Mix.Shell.IO.info "\tRequest per second: #{total_request / total_time * 1_000}"
    Mix.Shell.IO.info "\n\tPercentile: \n"
    for i <- [0.50, 0.80, 0.90, 0.95, 0.96, 0.97, 0.98, 0.99, 0.999, 0.9995, 0.9999, 0.99999] do
      time = Numerino.Tester.Analyzer.percentile(analytics, i).elapsed_time
      time = :erlang.convert_time_unit(time, :native, :micro_seconds)
      Mix.Shell.IO.info "\t\tOrder: #{i} \t #{time} \t\tμsec"
    end
  end

  defp first_run(url) do
    Numerino.Tester.generate_new(url)
    loop(url)
  end

  defp loop(url) do
    #:timer.sleep(round(10 * :rand.uniform))
    case :rand.uniform(105) do
      x when x <= 5 -> Numerino.Tester.generate_new(url)
      x when 5 < x and x <= 55 -> Numerino.Tester.pop(url)
      x when x > 55 -> Numerino.Tester.push(url)
    end
    loop(url)
  end

end

defmodule Numerino.Tester.Analyzer do

  defstruct queues: [], rounds: [], partition: HashDict.new

  def load_info do
    {queues, rounds} = Numerino.Tester.Collector.unload_data
    rounds = Enum.map(rounds, &analyze_round/1)
    queues = Enum.reduce(queues, HashDict.new, fn q, acc -> HashDict.put(acc, q.name, q) end)
    %Numerino.Tester.Analyzer{queues: queues, rounds: rounds}
  end

  defp analyze_round %{request_type: :new} = r do
    r
  end

  defp analyze_round %{request_type: :push} = r do
    %{response: %{body: body}} = r
    %{"message" => message, "priority" => priority, "status" => "ok"} = JSON.decode!(body)
    r |> Map.put(:message, message) |> Map.put(:priority, priority)
  end

  defp analyze_round %{request_type: :pop, status_code: 200} = r do
    %{response: %{body: body}} = r
    %{"message" => message, "priority" => priority} = JSON.decode!(body)
    r |> Map.put(:message, message) |> Map.put(:priority, priority)
  end

  defp analyze_round %{request_type: :pop} = r do
    %{response: %{body: body}} = r
    %{"message" => message} = JSON.decode!(body)
    r |> Map.put(:message, message)
  end

  def partition_by_queue %Numerino.Tester.Analyzer{rounds: rs, partition: p} = a do
    partition = Enum.reduce(rs, p, fn(r, acc)
      ->  Dict.update(acc, r.queue_name, [r], fn rounds -> [r | rounds] end)  
    end)
    %Numerino.Tester.Analyzer{a | partition: partition}
  end

  def order_partition %Numerino.Tester.Analyzer{partition: p} = a do
    
    p = p
    |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, &(&1.end_time))} end)
    |> Enum.into(%{})
    %Numerino.Tester.Analyzer{a | partition: p}
  end

  def check_correctness %Numerino.Tester.Analyzer{partition: p, queues: q} do
    Enum.map(Dict.keys(p), &is_correct(p[&1], q[&1].priorities))
  end

  defp is_correct partition, priorities do
    {priorities, _n} = Enum.reduce(priorities, {HashDict.new, 1}, fn p, {acc, i} -> {HashDict.put(acc, p, i), i+1} end)
    Enum.map_reduce(partition, {true, HeapQueue.new},
        fn p, {bool, q} ->
          if bool == false do 
            {{:skipped, p.request_type, p.message, (if Map.get(p, :priority), do: p.priority, else: nil), p.start_time, p.end_time}, {false, q}}
          else
            case p.request_type do
              :push -> {{:ok, :push, p.message, p.priority, p.start_time, p.end_time}, 
                        {true, HeapQueue.push(q, priorities[p.priority], p.message)}}
              :pop -> case p.response.status_code do
                        404 -> case HeapQueue.pop(q) do
                                  {:empty, new_queue} -> {{:ok, :pop, p.message, :no_priority, p.start_time, p.end_time}, 
                                                          {true, new_queue}}
                                  _ -> {{:wrong, :pop, p.message}, {false, q}}
                                end
                        200 -> message = p.message;
                               case HeapQueue.pop(q) do
                                  {{:value, _priority, ^message}, new_queue} -> {{:ok, :pop, p.message, p.priority, p.start_time, p.end_time}, 
                                                                                 {true, new_queue}}
                                  _ -> {{:wrong, :pop, p.message, nil, p.start_time, p.end_time}, {false, q}}
                                end
                      end
              :new -> {{:ok, p.request_type}, {true, q}}
            end
          end
        end)
  end

  def total_rounds %Numerino.Tester.Analyzer{rounds: rs} do
    length(rs)
  end

  def first_request_time %Numerino.Tester.Analyzer{rounds: rs} do
    Enum.min_by(rs, fn r -> r.start_time end).start_time
  end

  def last_response_time %Numerino.Tester.Analyzer{rounds: rs} do
    Enum.max_by(rs, fn r -> r.end_time end).end_time
  end

  def order_by_duration %Numerino.Tester.Analyzer{rounds: rs} = a do
    rounds = Enum.sort_by(rs, fn r -> r.elapsed_time end)
    %Numerino.Tester.Analyzer{a | rounds: rounds}
  end

  def percentile_sort(%Numerino.Tester.Analyzer{rounds: rs} = a, order) do
    percentile = round(Float.floor(order * length(rs)))
    analyzer = order_by_duration(a)
    Enum.at(analyzer.rounds, percentile)
  end
  
  def percentile(%Numerino.Tester.Analyzer{rounds: rs} = a, order) do
    percentile = round(Float.floor(order * length(rs)))
    Enum.at(a.rounds, percentile)
  end


end

defmodule Numerino.Tester.Collector do

  defstruct queues: [], rounds: []

  def start_link do
    Agent.start_link(fn -> %Numerino.Tester.Collector{} end, [name: Collector])
  end

  def new_queue queue do
    Agent.update(Collector,
      fn %Numerino.Tester.Collector{queues: q} = c
        -> %Numerino.Tester.Collector{c | queues: [queue | q]}
      end)
  end

  def new_round request_response do
    Agent.update(Collector, 
      fn %Numerino.Tester.Collector{rounds: r} = c
        -> %Numerino.Tester.Collector{c | rounds: [request_response | r]} 
      end)
  end

  def random_queue do
    Agent.get(Collector,
      fn %Numerino.Tester.Collector{queues: q}
        -> Enum.random(q)
      end)
  end

  def unload_data do
    Agent.get(Collector,
      fn %Numerino.Tester.Collector{queues: q, rounds: r}
        -> {q, r}
      end)
  end
end

defmodule Numerino.Tester do

  @queue_type ["transient"]
  @priority [
              ["1", "2", "3", "4", "5"],
              ["1", "2", "3"],
              ["high", "medium", "low"],
              ["critical", "high", "medium", "low"]
  ]

  @header [{"Content-Type", "application/json"}]

  def generate_new url do
    queue_type = Enum.random(@queue_type)
    priorities = Enum.random(@priority)
    body = JSON.encode!(%{type: queue_type, priorities: priorities})
    url = url <> "/" 
    {st1, mt1} = get_time
    {:ok, response} = HTTPoison.post(url, body, @header)
    {st2, mt2} = get_time
    %{status_code: 201, body: body} = response
    %{"queue" => %{"name" => name}} = JSON.decode!(body)
    Numerino.Tester.Collector.new_queue(%{name: name, queue_type: queue_type, priorities: priorities})
    Numerino.Tester.Collector.new_round(%{request_type: :new, 
          start_time: st1, end_time: st2, 
          elapsed_time: :erlang.convert_time_unit(mt2 - mt1, :native, :nano_seconds), 
          status_code: 201, response: response, queue_type: queue_type, queue_name: name})
  end

  def pop(url)do
    %{name: name, queue_type: queue_type} = Numerino.Tester.Collector.random_queue
    url = url <> "/" <> name
    {st1, mt1} = get_time
    {:ok, response} = HTTPoison.get(url, @header)
    {st2, mt2} = get_time
    %{status_code: status_code} = response
    Numerino.Tester.Collector.new_round(%{request_type: :pop, 
        start_time: st1, end_time: st2, 
        elapsed_time: :erlang.convert_time_unit(mt2 - mt1, :native, :nano_seconds), 
        status_code: status_code, response: response, queue_type: queue_type, queue_name: name})
  end

  def push(url) do
    %{name: name, queue_type: queue_type, priorities: priorities} = Numerino.Tester.Collector.random_queue
    url = url <> "/" <> name
    body = JSON.encode!(%{priority: Enum.random(priorities), message: UUID.uuid4})
    {st1, mt1} = get_time
    {:ok, response} = HTTPoison.post(url, body, @header)
    {st2, mt2} = get_time
    %{status_code: status_code} = response
    Numerino.Tester.Collector.new_round(%{request_type: :push, 
        start_time: st1, end_time: st2, 
        elapsed_time: :erlang.convert_time_unit(mt2 - mt1, :native, :nano_seconds), 
        status_code: status_code, response: response, queue_type: queue_type, queue_name: name})
  end

  defp get_time do
    {:erlang.system_time, :erlang.monotonic_time}
  end

end
