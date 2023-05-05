defmodule SimpleFsm do
  @moduledoc """
  Documentation for `SimpleFsm`.
  """

  @type field :: atom
  @type state :: atom | String.t()
  @type states :: [state(), ...]

  ## Public API

  @spec field(module() | struct()) :: field()
  def field(%mod{}), do: field(mod)
  def field(mod) when is_atom(mod), do: mod.__simple_fsm__(:field)

  @spec states(module() | struct()) :: states()
  def states(%mod{}), do: states(mod)
  def states(mod) when is_atom(mod), do: mod.__simple_fsm__(:states)

  @spec transitions(module() | struct()) :: %{state() => states()}
  def transitions(%mod{}), do: transitions(mod)
  def transitions(mod) when is_atom(mod), do: mod.__simple_fsm__(:transitions)

  @spec transitions(module() | struct(), state()) :: states()
  def transitions(%mod{}, state), do: transitions(mod, state)
  def transitions(mod, state) when is_atom(mod), do: mod.__simple_fsm__(:transitions, state)

  @spec transition_to(struct(), state()) ::
          {:ok, struct()}
          | {:error, :invalid_transition}
          | {:error, :unknown_state}
          | {:error, :unknown_target}
  def transition_to(struct, target_state) when is_struct(struct) do
    field = field(struct)
    states = states(struct)
    current_state = Map.fetch!(struct, field)

    with :ok <- maybe_valid_current_state(current_state, states),
         :ok <- maybe_valid_target_state(target_state, states),
         transitions <- transitions(struct, current_state),
         :ok <- maybe_valid_transition(target_state, transitions) do
      {:ok, Map.replace!(struct, field, target_state)}
    end
  end

  @spec transition_to!(struct(), state()) :: struct()
  def transition_to!(struct, target_state) do
    case transition_to(struct, target_state) do
      {:ok, new_struct} -> new_struct
      {:error, error} -> raise "invalid transition with error: #{inspect(error)}"
    end
  end

  defmacro __using__(opts) do
    caller = __CALLER__.module
    {field, transitions} = extract_opts!(opts, caller)
    states = get_states(transitions)
    transitions_full = expand_transitions(transitions)

    quote do
      @doc false
      def __simple_fsm__(:field), do: unquote(field)
      def __simple_fsm__(:states), do: unquote(states)
      def __simple_fsm__(:transitions), do: unquote(transitions_full)

      def __simple_fsm__(:transitions, state) do
        if state not in unquote(states) do
          raise ArgumentError, "unknown state #{inspect(state)} for #{inspect(unquote(caller))}"
        end

        Map.get(unquote(transitions_full), state, [])
      end
    end
  end

  ## Private Helpers

  defp ast_to_transitions({:%{}, _, transitions}), do: transitions
  defp ast_to_transitions(transitions) when is_list(transitions), do: transitions
  defp ast_to_transitions(_), do: nil

  defp extract_opts!(opts_ast, caller) do
    field = opts_ast[:field] || raise_arg!(":field is required", caller)
    transitions_ast = opts_ast[:transitions] || raise_arg!(":transitions is required", caller)

    transitions =
      ast_to_transitions(transitions_ast) ||
        raise_arg!(":transitions must be a map or keyword list", caller)

    {field, transitions}
  end

  defp raise_arg!(msg, caller) do
    raise ArgumentError, "#{msg} for a SimpleFSM in #{inspect(caller)}"
  end

  defp get_states(transitions) do
    transitions
    |> Enum.flat_map(fn
      {k, states} when is_list(states) -> [k | states]
      {k, state} when is_binary(state) or is_atom(state) -> [k, state]
    end)
    |> Enum.uniq()
  end

  defp expand_transitions(transitions) do
    transitions
    |> Enum.reduce(%{}, fn
      {from, to}, acc when is_list(to) -> Map.put(acc, from, to)
      {from, to}, acc -> Map.put(acc, from, [to])
    end)
    |> Macro.escape()
  end

  defp maybe_valid_current_state(state, states) do
    if Enum.member?(states, state), do: :ok, else: {:error, :unknown_state}
  end

  defp maybe_valid_target_state(state, states) do
    if Enum.member?(states, state), do: :ok, else: {:error, :unknown_target}
  end

  defp maybe_valid_transition(state, transitions) do
    if Enum.member?(transitions, state), do: :ok, else: {:error, :invalid_transition}
  end
end
