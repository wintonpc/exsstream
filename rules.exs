defmodule Rule do
  defstruct name: nil, deps: [], stream_gen: nil, stream: nil
end

defmodule Param do
  defstruct name: nil
end

defmodule Rules do
  import Rules.Ordering
  
  def define_rule(name, deps, stream_generator) do
    rule = %Rule{name: name, deps: deps, stream_gen: stream_generator}
    add(rule)
    rule
  end

  def wire do
    import Enum
    each ordered_rules(list), fn r ->
      args = r.deps |> map(&find/1) |> map(&(&1.stream)) |> to_list
      stream = r.stream_gen.(args)
      set_stream(r, stream)
    end
  end
  
  defp add(rule) do
    ensure_initialized
    Agent.update(:all_rules_agent, &(Map.put_new(&1, rule.name, rule)))
  end
  
  def list do
    ensure_initialized
    Agent.get(:all_rules_agent, &(Map.values(&1)))
  end

  def find(name) do
    ensure_initialized
    Agent.get(:all_rules_agent, &((&1)[name]))    
  end

  def set_stream(rule, stream) do
    ensure_initialized
    Agent.update(:all_rules_agent, &(put_in (&1)[rule.name].stream, stream))
  end

  defp ensure_initialized do
    import Process
    unless whereis(:all_rules_agent) do
      {:ok, pid} = Agent.start_link(fn -> %{} end)
      register(pid, :all_rules_agent)
    end
  end

  def reset do
    Agent.stop(:all_rules_agent)
    Process.unregister(:all_rules_agent)
  end

  def test do
    Rules.define_rule("foo", [], fn([]) -> 1..5 end)
    Rules.define_rule("bar", ["foo"], fn([f]) -> f |> Stream.map(&(&1 * &1)) end)
    Rules.wire
    Rules.find("bar").stream
  end
end

IO.puts inspect(Enum.to_list(Rules.test))
