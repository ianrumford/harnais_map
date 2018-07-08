defmodule Harnais.Map do

  @moduledoc ~S"""
  Functions for Testing Maps

  ## Documentation Terms

  In the documentation these terms, usually in *italics*, are used to mean the same thing.

  ### *opts*

  An *opts* is a `Keyword` list.

  ## Bang and Query Functions

  All functions have bang and query peers.

  These functions do not appear in the function list to stop clutter. (They are `@doc false`).

  ## Errors

  Errors are managed by `Harnais.Error`.

  The doctests include examples where the exception message
  (`Exception.message/1`) is shown. Other doctests export the
  exception (`Harnais.Error.export_exception/1`) and show the
  exception details.
  """

  use Plymio.Codi
  use Harnais.Attribute
  use Harnais.Attribute.Data
  use Harnais.Error.Attribute

  @codi_opts [
    {@plymio_codi_key_vekil, Plymio.Vekil.Codi.__vekil__},
  ]

  import Harnais.Error, only: [
    new_error_result: 1,
    new_errors_result: 1,
  ]

  import Plymio.Fontais.Option, only: [
    opts_create_aliases_dict: 1,
    opts_canonical_keys: 2,
    opts_get: 3,
  ]

  import Plymio.Funcio.Enum.Map.Gather, only: [
    map_gather0_enum: 2,
  ]

  @type opts :: Harnais.opts
  @type error :: Harnais.error

  @harnais_map_error_message_map_invalid "map invalid"
  @harnais_map_error_message_map_compare_failed "map compare failed"

  @harnais_map_compare_worker_kvs_aliases [
    {@harnais_key_filter_keys, nil},
    {@harnais_key_compare_values, nil},
  ]

  @harnais_map_compare_worker_dict_aliases @harnais_map_compare_worker_kvs_aliases
  |> opts_create_aliases_dict

  @doc false
  def opts_canonical_compare_worker_opts(opts, dict \\ @harnais_map_compare_worker_dict_aliases) do
    opts |> opts_canonical_keys(dict)
  end

  defp map_compare_worker(map1, map2, opts) when is_map(map1) and is_map(map2) do

    with {:ok, opts} <- opts |>  opts_canonical_compare_worker_opts,
         {:ok, fun_filter_keys} <- opts |> opts_get(@harnais_key_filter_keys, fn _ -> true end),
         {:ok, fun_filter_keys} <- fun_filter_keys |> Plymio.Funcio.Predicate.Utility.validate_predicate1_fun,
         {:ok, fun_compare_values} <- opts |> opts_get(@harnais_key_compare_values, fn _loc, v1, v2 -> v1 == v2 end),
           true <- true do

      Map.keys(map1) ++ Map.keys(map2)
      |> Enum.uniq
      |> Enum.filter(fun_filter_keys)
      # this will drop nil or unset results
      |> map_gather0_enum(
      fn k ->

        map1
        |> Map.fetch(k)
        |> case do

             {:ok, map1_v} ->

               map2
               |> Map.fetch(k)
               |> case do

                    {:ok, map2_v} ->

                      fun_compare_values.(k, map1_v, map2_v)
                      |> case do

                           true -> {:ok, k}

                           x when x in [nil, false]  ->

                               new_error_result(
                                 t: :value,
                                 m: @harnais_map_error_message_map_compare_failed,
                                 r: @harnais_error_reason_mismatch,
                                 i: k,
                                 v1: map1_v,
                                 v2: map2_v)

                             {:ok, _} -> @plymio_fontais_the_unset_value
                             {:error, %{__exception__: true}} = result -> result

                         end

                    # key not in map2
                    _ ->

                      new_error_result(
                        t: @harnais_error_value_field_type_key,
                        m: @harnais_map_error_message_map_compare_failed,
                        r: @harnais_error_reason_missing,
                        i: k,
                        v1: map1_v,
                        v2: @harnais_error_status_value_no_value)

                  end

             # key not in map1
             _ ->

               new_error_result(
                 t: @harnais_error_value_field_type_key,
                 m: @harnais_map_error_message_map_compare_failed,
                 r: @harnais_error_reason_missing,
                 i: k,
                 v1: @harnais_error_status_value_no_value,
                 v2: map2 |> Map.get(k))

           end

      end)
      |> case do
           {:error, %{__struct__: _}} = result -> result
           {:ok, gather_opts} ->

             gather_opts
             |> Plymio.Fontais.Funcio.gather_opts_has_error?
             |> case do

                  true ->

                    with {:ok, errors} <- gather_opts |> Plymio.Fontais.Funcio.gather_opts_error_values_get,
                         {:ok, error} <- [add_errors: errors] |> Harnais.Error.Status.new do
                      {:error, error}
                    else
                      {:error, %{__exception__: true}} = result -> result
                    end

                  # no errors
                  _ ->

                    {:ok, map1}

                end

         end

    else
      {:error, %{__exception__: true}} = result -> result
    end

  end

  @doc ~S"""
  `harnais_map_compare/3` takes two arguments, expected to be maps, together with (optional) *opts* and compares them key by key.

  If the maps are equal its returns `{:ok, map1}`.

  If the maps are not equal in any way, its returns `{:error, error}`

  If either argument is a `Keyword`, it is converted into a `Map` first.

  The default is to compare all keys but this can be overriden
  using the `:filter_keys` option with a function of arity 1 which is
  passed the `key` and should return `true` or `false`.

  The default is to use `Kernel.==/2` to compare the values of each
  key. A `falsy` result will cause a new error to be added.

  The compare function can be overriden using the `:compare_values` option
  together with a function of arity 3 which is passed the `key`, `value1` and
  `value2` and should return `true`, `false`, `nil`, `{:ok, value}`
  or `{error, error}`.

  ## Examples

      iex> harnais_map_compare(%{}, %{})
      {:ok, %{}}

      iex> harnais_map_compare(%{a: 1}, %{a: 1})
      {:ok, %{a: 1}}

      iex> {:error, error} = harnais_map_compare(%{a: 1}, :not_a_map)
      ...> error |> Exception.message
      "map compare failed, got: :not_a_map"

      iex> {:error, error} = harnais_map_compare(%{a: 1}, :not_a_map)
      ...> error|> Harnais.Error.export_exception
      {:ok, [error: [[m: "map compare failed",
                      r: :not_map,
                      t: :arg,
                      l: 1,
                      v: :not_a_map]]]}

  A `Keyword` can be provided as either (or both) maps but the `value` in `{:ok, value}` will be the first argument:

      iex> harnais_map_compare(%{a: 1}, [a: 1])
      {:ok, %{a: 1}}

      iex> harnais_map_compare([a: 1], %{a: 1})
      {:ok, [a: 1]}

  If the first argument is a *struct* and the second a `Keyword`, the
  *struct*'s name is added to the "mapified" second argument.

      iex> harnais_map_compare(%{__struct__: __MODULE__, a: 1}, [a: 1])
      {:ok, %{__struct__: __MODULE__, a: 1}}

  Here the key (`:a`) is missing in the second map:

      iex> {:error, error} = harnais_map_compare(%{a: 1}, %{})
      ...> error |> Exception.message
      "map compare failed, reason=:missing, type=:key, location=:a, value1=1, value2=:no_value"

      iex> {:error, error} = harnais_map_compare(%{a: 1}, [])
      ...> error |> Harnais.Error.export_exception
      {:ok, [error: [[m: "map compare failed",
                      r: :missing,
                      t: :key,
                      l: :a,
                      v1: 1,
                      v2: :no_value]]]}

  Here the values of the `:a` key are different:

      iex> {:error, error} = harnais_map_compare(%{a: 1}, %{a: 2})
      ...> error |> Exception.message
      "map compare failed, reason=:mismatch, type=:value, location=:a, value1=1, value2=2"

  Here the keys do not match and this generates multiple errors:

      iex> {:error, error} = harnais_map_compare(%{a: 1}, %{b: 2})
      ...> error |> Exception.message
      "map compare failed, reason=:missing, type=:key, location=:a, value1=1, value2=:no_value; map compare failed, reason=:missing, type=:key, location=:b, value1=:no_value, value2=2"

  When there are multiple errors, it can be easier to understand the differences by gathering the exception export:

      iex> {:error, error} = harnais_map_compare(%{a: 1}, %{b: 2})
      ...> {:ok, export} = error |> Harnais.Error.export_exception
      ...> export |> Harnais.Error.gather_export
      {:ok, [error: [[m: "map compare failed",
                      r: :missing,
                      t: :key,
                      l: :a,
                      v1: 1,
                      v2: :no_value],
                     [m: "map compare failed",
                      r: :missing,
                      t: :key,
                      l: :b,
                      v1: :no_value,
                      v2: 2]]]}

  In this example a `:compare_values` function is provided that always returns `true`:

      iex> harnais_map_compare(%{a: 1}, %{a: 2}, compare_values: fn _,_,_ -> true end)
      {:ok, %{a: 1}}

  This `:compare_values` function always returns `false` failing two maps that are in fact equal:

      iex> {:error, error} = harnais_map_compare(%{a: 1}, %{a: 1}, compare_values: fn _,_,_ -> false end)
      ...> error |> Exception.message
      "map compare failed, reason=:mismatch, type=:value, location=:a, value1=1, value2=1"

  The `:filter_keys` function can be used to select the keys for comparision:

      iex> harnais_map_compare(%{a: 1, b: 21, c: 3}, %{a: 1, b: 22, c: 3},
      ...>   filter_keys: fn
      ...>      # don't compare b's values
      ...>      :b -> false
      ...>      _ -> true
      ...>   end)
      {:ok, %{a: 1, b: 21, c: 3}}

      iex> harnais_map_compare(%{a: 1, b: 21, c: 3}, %{a: 1, c: 3},
      ...>   filter_keys: fn
      ...>      # don't compare b's values (or spot missing key)
      ...>      :b -> false
      ...>      _ -> true
      ...>   end)
      {:ok, %{a: 1, b: 21, c: 3}}

  Query examples:

      iex> harnais_map_compare?(%{a: 1}, %{a: 1})
      true

      iex> harnais_map_compare?(%{__struct__: __MODULE__, a: 1}, [a: 1])
      true

      iex> harnais_map_compare?(%{a: 1}, %{b: 2})
      false

      iex> harnais_map_compare?(%{a: 1, b: 21, c: 3}, %{a: 1, c: 3},
      ...>   filter_keys: fn
      ...>      # don't compare b's values (or spot missing key)
      ...>      :b -> false
      ...>      _ -> true
      ...>   end)
      true

  Bang examples:

      iex> harnais_map_compare!(%{a: 1}, %{a: 1})
      %{a: 1}

      iex> harnais_map_compare!(%{a: 1}, %{b: 2})
      ** (Harnais.Error.Status) map compare failed, reason=:missing, type=:key, location=:a, value1=1, value2=:no_value; map compare failed, reason=:missing, type=:key, location=:b, value1=:no_value, value2=2
  """

  @since "0.1.0"

  @spec harnais_map_compare(any, any, opts) :: {:ok, map} | {:error, error}

  def harnais_map_compare(map1, map2, opts \\ [])

  def harnais_map_compare(%{__struct__: map1_struct_name} = map1, arg2, opts) when is_list(arg2) do

    arg2
    |> map_normalise
    |> case do

         {:ok, map2} ->

           harnais_map_compare(map1, map2 |> Map.put(:__struct__, map1_struct_name), opts)

         _ ->

           new_error_result(
             message_config: [:message, :value],
             t: @harnais_error_value_field_type_arg,
             m: @harnais_map_error_message_map_compare_failed,
             r: @harnais_error_reason_not_map,
             i: 1,
             v: arg2)

       end

  end

  def harnais_map_compare(map1, map2, opts) do

    # build errors incrementally
    [map1, map2]
    |> Stream.with_index
    |> map_gather0_enum(fn {value, ndx}  ->

      value
      |> map_normalise
      |> case do
           {:ok, _} = result -> result

           _ ->

             new_error_result(
               message_config: [:message, :value],
               t: @harnais_error_value_field_type_arg,
               m: @harnais_map_error_message_map_compare_failed,
               r: @harnais_error_reason_not_map,
               i: ndx,
               v: value)

         end

    end)
    |> case do
         {:error, %{__struct__: _}} = result -> result
         {:ok, gather_opts} ->

           gather_opts
           |> Plymio.Fontais.Funcio.gather_opts_has_error?
           |> case do

                true ->

                  with {:ok, errors} <- gather_opts |> Plymio.Fontais.Funcio.gather_opts_error_values_get,
                    {:ok, error} <- errors |> new_errors_result do
                    {:error, error}
                  else
                    {:error, %{__exception__: true}} = result -> result
                  end

                # no errors yet
                _ ->

                  with {:ok, [map1_norm, map2_norm]} <- gather_opts
                          |> Plymio.Fontais.Funcio.gather_opts_ok_values_get do

                    map_compare_worker(map1_norm, map2_norm, opts)
                    |> case do
                         {:error, %{__struct__: _}} = result -> result
                         {:ok, _} -> {:ok, map1}
                       end

                  else
                    {:error, %{__exception__: true}} = result -> result
                  end

              end

       end

  end

  @doc ~S"""
  `harnais_map/1` tests whether the argument is a `Map` and,
   if true, returns `{:ok, argument}` else `{:error, error}`.

  ## Examples

      iex> harnais_map(%{a: 1})
      {:ok, %{a: 1}}

      iex> {:error, error} = harnais_map(42)
      ...> error |> Harnais.Error.export_exception
      {:ok, [error: [[m: "map invalid", r: :not_map, t: :arg, v: 42]]]}

      iex> {:error, error} = harnais_map(:atom)
      ...> error |> Exception.message
      "map invalid, got: :atom"

  Query examples:

      iex> harnais_map?(%{a: 1})
      true

      iex> harnais_map?(42)
      false

      iex> harnais_map?([1, 2, 3])
      false

  Bang examples:

      iex> harnais_map!(%{a: 1})
      %{a: 1}

      iex> harnais_map!(42)
      ** (Harnais.Error) map invalid, got: 42

      iex> harnais_map!([1, 2, 3])
      ** (Harnais.Error) map invalid, got: [1, 2, 3]

  """

  @since "0.1.0"

  @spec harnais_map(any) :: {:ok, map} | {:error, error}

    def harnais_map(value) when is_map(value) do
    {:ok, value}
  end

  def harnais_map(value) when is_map(value) do
    {:ok, value}
  end

  def harnais_map(value) do

    new_error_result(
      message_config: [:message, :value],
      t: @harnais_error_value_field_type_arg,
      m: @harnais_map_error_message_map_invalid,
      r: @harnais_error_reason_not_map,
      v: value)

  end

  defp map_normalise(map)

  defp map_normalise(map) when is_map(map) do
    {:ok, map}
  end

  defp map_normalise(value) when is_list(value) do

    value
    |> Keyword.keyword?
    |> case do
         true ->

           {:ok, value |> Enum.into(%{})}

         _ ->

           value |> harnais_map
       end

  end

  defp map_normalise(value) do
    value |> harnais_map
  end

  @quote_result_map_no_return quote(do: map | no_return)

  [

    delegate: [doc: false, name: :harnais_map?, as: :is_map, to: Kernel, args: :map, since: "0.1.0", result: :boolean],

    bang: [doc: false, as: :harnais_map, args: :map, since: "0.1.0", result: @quote_result_map_no_return],

    bang: [doc: false, as: :harnais_map_compare, args: [:map1, :map2], since: "0.1.0", result: @quote_result_map_no_return],
    query: [doc: false, as: :harnais_map_compare, args: [:map1, :map2], since: "0.1.0", result: true],

    bang: [doc: false, as: :harnais_map_compare, args: [:map1, :map2, :opts], since: "0.1.0", result: @quote_result_map_no_return],
    query: [doc: false, as: :harnais_map_compare, args: [:map1, :map2, :opts], since: "0.1.0", result: true],

  ]
  |> Enum.flat_map(fn {pattern,opts} ->
    [pattern: [pattern: pattern] ++ opts]
  end)
  |> CODI.reify_codi(@codi_opts)

end

