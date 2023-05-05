defmodule SimpleFsmTest do
  use ExUnit.Case, async: true

  defmodule MyApp.Switch do
    use SimpleFsm,
      field: :state,
      transitions: [on: :off, off: :on]

    defstruct state: :off
  end

  defmodule MyApp.ComplexFSM do
    use SimpleFsm,
      field: :state,
      transitions: %{
        "one" => ["two", "three"],
        "two" => ["three", "four"],
        "three" => "four"
      }

    defstruct state: "one", foo: :bar
  end

  test "define __using__/1" do
    code = """
    defmodule MyApp.FSM do
      use SimpleFsm, field: :state, transitions: [state1: :state2]
      defstruct state: :state1
    end
    """

    assert {:ok, _} = try_to_eval(code)
  end

  describe "field/1" do
    test "return all field" do
      assert SimpleFsm.field(MyApp.Switch) == :state
      assert SimpleFsm.field(%MyApp.Switch{}) == :state
    end
  end

  describe "states/1" do
    test "returns all states" do
      assert SimpleFsm.states(MyApp.Switch) == [:on, :off]
      assert SimpleFsm.states(%MyApp.Switch{}) == [:on, :off]
    end

    test "doesn't return wildcard states" do
      assert SimpleFsm.states(MyApp.ComplexFSM) == ["one", "two", "three", "four"]
    end
  end

  describe "transitions/1" do
    test "returns all transitions" do
      assert SimpleFsm.transitions(MyApp.Switch) == %{on: [:off], off: [:on]}
      assert SimpleFsm.transitions(%MyApp.Switch{}) == %{on: [:off], off: [:on]}

      assert SimpleFsm.transitions(MyApp.ComplexFSM) == %{
               "one" => ["two", "three"],
               "two" => ["three", "four"],
               "three" => ["four"]
             }
    end
  end

  describe "transitions/2" do
    test "returns all transitions for the given state" do
      assert SimpleFsm.transitions(MyApp.Switch, :on) == [:off]
      assert SimpleFsm.transitions(%MyApp.Switch{}, :on) == [:off]

      assert SimpleFsm.transitions(MyApp.ComplexFSM, "one") == ["two", "three"]
      assert SimpleFsm.transitions(MyApp.ComplexFSM, "two") == ["three", "four"]
      assert SimpleFsm.transitions(MyApp.ComplexFSM, "three") == ["four"]
      assert SimpleFsm.transitions(MyApp.ComplexFSM, "four") == []
    end
  end

  describe "transition_to/2" do
    test "transition is the state is valid" do
      assert SimpleFsm.transition_to(%MyApp.Switch{state: :on}, :off) ==
               {:ok, %MyApp.Switch{state: :off}}

      assert SimpleFsm.transition_to(%MyApp.Switch{state: :off}, :on) ==
               {:ok, %MyApp.Switch{state: :on}}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "one"}, "two") ==
               {:ok, %MyApp.ComplexFSM{state: "two", foo: :bar}}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "two"}, "four") ==
               {:ok, %MyApp.ComplexFSM{state: "four", foo: :bar}}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "three"}, "four") ==
               {:ok, %MyApp.ComplexFSM{state: "four", foo: :bar}}
    end

    test "returns an error tuple when the target is invalid" do
      assert SimpleFsm.transition_to(%MyApp.Switch{state: :on}, :on) ==
               {:error, :invalid_transition}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "one"}, "four") ==
               {:error, :invalid_transition}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "four"}, "one") ==
               {:error, :invalid_transition}
    end

    test "returns an error when states doesn't exists" do
      assert SimpleFsm.transition_to(%MyApp.Switch{state: :foo}, :on) ==
               {:error, :unknown_state}

      assert SimpleFsm.transition_to(%MyApp.Switch{state: :on}, :foo) ==
               {:error, :unknown_target}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "five"}, "one") ==
               {:error, :unknown_state}

      assert SimpleFsm.transition_to(%MyApp.ComplexFSM{state: "one"}, "five") ==
               {:error, :unknown_target}
    end
  end

  describe "transition_to!/2" do
    test "transition is the state is valid" do
      assert SimpleFsm.transition_to!(%MyApp.Switch{state: :on}, :off) ==
               %MyApp.Switch{state: :off}

      assert SimpleFsm.transition_to!(%MyApp.Switch{state: :off}, :on) ==
               %MyApp.Switch{state: :on}

      assert SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "one"}, "two") ==
               %MyApp.ComplexFSM{state: "two", foo: :bar}

      assert SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "two"}, "four") ==
               %MyApp.ComplexFSM{state: "four", foo: :bar}

      assert SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "three"}, "four") ==
               %MyApp.ComplexFSM{state: "four", foo: :bar}
    end

    test "raises an error tuple when the target is invalid" do
      assert_raise RuntimeError, "invalid transition with error: :invalid_transition", fn ->
        SimpleFsm.transition_to!(%MyApp.Switch{state: :on}, :on)
      end

      assert_raise RuntimeError, "invalid transition with error: :invalid_transition", fn ->
        SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "one"}, "four")
      end

      assert_raise RuntimeError, "invalid transition with error: :invalid_transition", fn ->
        SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "four"}, "one")
      end
    end

    test "raises an error when states doesn't exists" do
      assert_raise RuntimeError, "invalid transition with error: :unknown_state", fn ->
        SimpleFsm.transition_to!(%MyApp.Switch{state: :foo}, :on)
      end

      assert_raise RuntimeError, "invalid transition with error: :unknown_target", fn ->
        SimpleFsm.transition_to!(%MyApp.Switch{state: :on}, :foo)
      end

      assert_raise RuntimeError, "invalid transition with error: :unknown_state", fn ->
        SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "five"}, "one")
      end

      assert_raise RuntimeError, "invalid transition with error: :unknown_target", fn ->
        SimpleFsm.transition_to!(%MyApp.ComplexFSM{state: "one"}, "five")
      end
    end
  end

  ## Helpers

  defp try_to_eval(code) do
    {:ok, Code.eval_string(code)}
  rescue
    error -> {:error, error}
  end
end
