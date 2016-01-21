defmodule Rule do
  defstruct name: nil, stream: nil
end

defmodule Param do
  defstruct name: nil
end

defmodule Rules do

  def define_rule(name, deps, stream_generator) do
    rule = %Rule{name: name, stream: stream_generator}
    add(rule)
    rule
  end

  def wire do
    Enum.each list, fn r ->
      stream = r.stream.()
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
end
