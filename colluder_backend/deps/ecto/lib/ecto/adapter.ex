defmodule Ecto.Adapter do
  @moduledoc """
  This module specifies the adapter API that an adapter is required to
  implement.
  """

  @type t :: module

  @typedoc "Ecto.Query metadata fields (stored in cache)"
  @type query_meta :: %{prefix: binary | nil, sources: tuple, assocs: term,
                        preloads: term, select: term, fields: [term]}

  @typedoc "Ecto.Schema metadata fields"
  @type schema_meta :: %{source: source, schema: atom, context: term, autogenerate_id: {atom, :id | :binary_id}}

  @type source :: {prefix :: binary | nil, table :: binary}
  @type fields :: Keyword.t
  @type filters :: Keyword.t
  @type constraints :: Keyword.t
  @type returning :: [atom]
  @type prepared :: term
  @type cached :: term
  @type process :: (field :: Macro.t, value :: term, context :: term -> term)
  @type autogenerate_id :: {field :: atom, type :: :id | :binary_id, value :: term} | nil

  @typep repo :: Ecto.Repo.t
  @typep options :: Keyword.t

  @doc """
  The callback invoked in case the adapter needs to inject code.
  """
  @macrocallback __before_compile__(env :: Macro.Env.t) :: Macro.t

  @doc """
  Ensure all applications necessary to run the adapter are started.
  """
  @callback ensure_all_started(repo, type :: :application.restart_type) ::
    {:ok, [atom]} | {:error, atom}

  @doc """
  Returns the childspec that starts the adapter process.
  """
  @callback child_spec(repo, options) :: Supervisor.Spec.spec

  ## Types

  @doc """
  Returns the loaders for a given type.

  It receives the primitive type and the Ecto type (which may be
  primitive as well). It returns a list of loaders with the given
  type usually at the end.

  This allows developers to properly translate values coming from
  the adapters into Ecto ones. For example, if the database does not
  support booleans but instead returns 0 and 1 for them, you could
  add:

      def loaders(:boolean, type), do: [&bool_decode/1, type]
      def loaders(_primitive, type), do: [type]

      defp bool_decode(0), do: {:ok, false}
      defp bool_decode(1), do: {:ok, true}

  All adapters are required to implement a clause for `:binary_id` types,
  since they are adapter specific. If your adapter does not provide binary
  ids, you may simply use Ecto.UUID:

      def loaders(:binary_id, type), do: [Ecto.UUID, type]
      def loaders(_primitive, type), do: [type]

  """
  @callback loaders(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
            [(term -> {:ok, term} | :error) | Ecto.Type.t]

  @doc """
  Returns the dumpers for a given type.

  It receives the primitive type and the Ecto type (which may be
  primitive as well). It returns a list of dumpers with the given
  type usually at the beginning.

  This allows developers to properly translate values coming from
  the Ecto into adapter ones. For example, if the database does not
  support booleans but instead returns 0 and 1 for them, you could
  add:

      def dumpers(:boolean, type), do: [type, &bool_encode/1]
      def dumpers(_primitive, type), do: [type]

      defp bool_encode(false), do: {:ok, 0}
      defp bool_encode(true), do: {:ok, 1}

  All adapters are required to implement a clause or :binary_id types,
  since they are adapter specific. If your adapter does not provide
  binary ids, you may simply use Ecto.UUID:

      def dumpers(:binary_id, type), do: [type, Ecto.UUID]
      def dumpers(_primitive, type), do: [type]

  """
  @callback dumpers(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
            [(term -> {:ok, term} | :error) | Ecto.Type.t]

  @doc """
  Called to autogenerate a value for id/embed_id/binary_id.

  Returns the autogenerated value, or nil if it must be
  autogenerated inside the storage or raise if not supported.
  """
  @callback autogenerate(field_type :: :id | :binary_id | :embed_id) :: term | nil | no_return

  @doc """
  Commands invoked to prepare a query for `all`, `update_all` and `delete_all`.

  The returned result is given to `execute/6`.
  """
  @callback prepare(atom :: :all | :update_all | :delete_all, query :: Ecto.Query.t) ::
              {:cache, prepared} | {:nocache, prepared}

  @doc """
  Executes a previously prepared query.

  It must return a tuple containing the number of entries and
  the result set as a list of lists. The result set may also be
  `nil` if a particular operation does not support them.

  The `meta` field is a map containing some of the fields found
  in the `Ecto.Query` struct.

  It receives a process function that should be invoked for each
  selected field in the query result in order to convert them to the
  expected Ecto type. The `process` function will be nil if no
  result set is expected from the query.
  """
  @callback execute(repo, query_meta, query, params :: list(), process | nil, options) :: result when
              result: {integer, [[term]] | nil} | no_return,
              query: {:nocache, prepared} |
                     {:cached, cached} |
                     {:cache, (cached -> :ok), prepared}

  @doc """
  Inserts multiple entries into the data store.
  """
  @callback insert_all(repo, schema_meta, header :: [atom], [fields], returning, options) ::
              {integer, [[term]] | nil} | no_return

  @doc """
  Inserts a single new struct in the data store.

  ## Autogenerate

  The primary key will be automatically included in `returning` if the
  field has type `:id` or `:binary_id` and no value was set by the
  developer or none was autogenerated by the adapter.
  """
  @callback insert(repo, schema_meta, fields, returning, options) ::
                    {:ok, fields} | {:invalid, constraints} | no_return

  @doc """
  Updates a single struct with the given filters.

  While `filters` can be any record column, it is expected that
  at least the primary key (or any other key that uniquely
  identifies an existing record) be given as a filter. Therefore,
  in case there is no record matching the given filters,
  `{:error, :stale}` is returned.
  """
  @callback update(repo, schema_meta, fields, filters, returning, options) ::
                    {:ok, fields} | {:invalid, constraints} |
                    {:error, :stale} | no_return

  @doc """
  Deletes a single struct with the given filters.

  While `filters` can be any record column, it is expected that
  at least the primary key (or any other key that uniquely
  identifies an existing record) be given as a filter. Therefore,
  in case there is no record matching the given filters,
  `{:error, :stale}` is returned.
  """
  @callback delete(repo, schema_meta, filters, options) ::
                     {:ok, fields} | {:invalid, constraints} |
                     {:error, :stale} | no_return
end