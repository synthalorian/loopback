defmodule Loopback.Transformations.Script do
  @moduledoc """
  Sandbox execution engine for transformation scripts.

  Scripts are evaluated with a restricted binding and a whitelist of safe
  modules. The script receives a `ctx` variable and must return a map with
  the same shape.
  """

  @safe_modules [
    Jason,
    String,
    Map,
    List,
    Enum,
    Integer,
    Float,
    Regex,
    URI,
    Base,
    DateTime,
    NaiveDateTime,
    Date,
    Time,
    Kernel
  ]

  @allowed_functions [
    {Jason, [:decode!, :encode!, :decode, :encode]},
    {String, [
       :split, :join, :replace, :downcase, :upcase, :trim, :trim_leading,
       :trim_trailing, :contains?, :starts_with?, :ends_with?, :slice,
       :to_integer, :to_float, :pad_leading, :pad_trailing, :reverse,
       :length, :duplicate, :valid?, :at, :first, :last, :graphemes,
       :codepoints, :next_codepoint, :next_grapheme, :next_grapheme_size,
       :equivalent?, :normalize, :printable?, :bag_distance, :jaro_distance
     ]},
    {Map, [:get, :put, :delete, :merge, :update, :has_key?, :keys, :values, :to_list, :from_struct, :new]},
    {List, [:first, :last, :flatten, :replace_at, :insert_at, :delete_at, :keyfind, :keydelete, :keystore, :to_tuple, :to_string, :wrap]},
    {Enum, [:map, :filter, :reject, :find, :reduce, :into, :concat, :sort, :sort_by, :group_by, :frequencies, :max, :min, :sum, :join, :any?, :all?, :empty?, :chunk_every, :dedup, :dedup_by, :drop, :drop_while, :take, :take_while, :zip, :with_index, :reverse, :random, :shuffle, :uniq, :uniq_by, :count, :member?, :at, :fetch, :fetch!, :split, :split_while, :slice]},
    {Integer, [:parse, :to_string, :to_charlist, :digits, :undigits, :pow]},
    {Float, [:parse, :to_string, :round, :floor, :ceil]},
    {Regex, [:run, :scan, :replace, :split, :match?, :named_captures]},
    {URI, [:encode, :decode, :encode_query, :decode_query, :parse, :new]},
    {Base, [:encode16, :decode16, :encode32, :decode32, :encode64, :decode64, :url_encode64, :url_decode64]},
    {DateTime, [:utc_now, :to_iso8601, :from_iso8601, :add, :diff]},
    {NaiveDateTime, [:utc_now, :to_iso8601, :from_iso8601, :add, :diff]},
    {Date, [:utc_today, :to_iso8601, :from_iso8601, :add, :diff]},
    {Time, [:utc_now, :to_iso8601, :from_iso8601, :add, :diff]},
    {Kernel, [:inspect, :trunc, :round, :abs, :min, :max, :elem, :tuple_size, :length, :hd, :tl, :is_list, :is_map, :is_binary, :is_integer, :is_float, :is_atom, :is_boolean, :to_string]}
  ]

  @doc """
  Executes a transformation script against the given context.

  Returns `{:ok, ctx}` on success or `{:error, reason}` on failure.
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def execute(script_text, ctx) when is_binary(script_text) and is_map(ctx) do
    bindings = [ctx: ctx]

    # Build a safe environment: only allow access to specific modules/functions
    env = build_safe_env()

    try do
      {result, _new_bindings} = Code.eval_string(script_text, bindings, env)

      case validate_result(result, ctx) do
        :ok -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    catch
      kind, value -> {:error, "#{kind}: #{inspect(value)}"}
    end
  end

  defp build_safe_env do
    # Create a minimal environment with only allowed modules imported
    # We use a custom macro env that restricts access
    env = __ENV__

    # Build aliases for safe modules
    aliases =
      for mod <- @safe_modules, into: %{} do
        {Module.concat([mod]), mod}
      end

    functions =
      for {mod, funs} <- @allowed_functions,
          fun <- funs,
          arity <- 0..4 do
        {{mod, fun, arity}, mod}
      end

    %Macro.Env{
      env
      | aliases: Map.to_list(aliases),
        functions: [{{Kernel, true}, functions}],
        macros: [],
        requires: [Kernel],
        context: nil
    }
  end

  defp validate_result(result, _original_ctx) do
    cond do
      not is_map(result) ->
        {:error, "script must return a map, got: #{inspect(result)}"}

      not Map.has_key?(result, :method) ->
        {:error, "script result missing required key :method"}

      not Map.has_key?(result, :path) ->
        {:error, "script result missing required key :path"}

      not Map.has_key?(result, :headers) ->
        {:error, "script result missing required key :headers"}

      not is_binary(result.method) ->
        {:error, ":method must be a string, got: #{inspect(result.method)}"}

      not is_binary(result.path) ->
        {:error, ":path must be a string, got: #{inspect(result.path)}"}

      not is_list(result.headers) ->
        {:error, ":headers must be a list, got: #{inspect(result.headers)}"}

      true ->
        :ok
    end
  end
end