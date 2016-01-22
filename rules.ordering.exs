defmodule Rules.Ordering do
  def ordered_rules(rules) do
    import Enum
    g = :digraph.new
    each rules, fn r ->
      :digraph.add_vertex(g, r.name)
    end
    each rules, fn r ->
      each r.deps, fn d ->
        :digraph.add_edge(g, r.name, d)
      end
    end
    order = :digraph_utils.topsort(g) |> reverse
    :digraph.delete(g)
    reorder(rules, order, &(&1.name))
  end

  defp reorder(xs, order, get_key) do
    Enum.map(order, fn o -> findp(xs, fn x -> get_key.(x) == o end) end)
  end

  defp findp(xs, pred) do
    xs |> Enum.filter(pred) |> hd
  end
  
  defp list_to_map(xs, get_key, get_val), do: list_to_map(xs, %{}, get_key, get_val)
  defp list_to_map([], m, _, _), do: m
  defp list_to_map([x|xs], m, get_key, get_val) do
    m2 = Map.put_new(m, get_key.(x), get_val.(x))
    list_to_map(xs, m2, get_key, get_val)
  end
end
