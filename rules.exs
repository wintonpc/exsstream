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
      stream = DStream.div(r.stream_gen.(args))
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
    import Stream
    
    small? = fn x ->
      trace("small?", x)
      x <= 5
    end
    odd? = fn x ->
      trace("odd?", x)
      rem(x, 2) != 0
    end
    square = fn x ->
      trace("square", x)
      x * x
    end
    negate = fn x ->
      trace("negate", x)
      -x
    end
    to_s = fn x ->
      trace("to_s", x)
      inspect(x)
    end

    Rules.define_rule("a", [], fn([]) -> unfold(1, up_to(5)) end)
    Rules.define_rule("b", ["a"], fn([a]) -> a |> map(square) end)
    Rules.define_rule("c", ["a"], fn([a]) -> a |> map(negate) end)
    Rules.define_rule("d", ["b", "c"], fn([b, c]) -> zip(b, c) end)
    Rules.wire
    Rules.find("d").stream
  end

  def up_to(max) do
    fn next ->
      if next <= max do
        trace("generate", next)
        {next, next+1}
      else
        nil
      end
    end
  end
  
  defp trace(name, arg) do
    IO.puts "#{name}(#{inspect arg}) on #{inspect self()}"
  end

end

IO.puts inspect(Enum.to_list(Rules.test))
