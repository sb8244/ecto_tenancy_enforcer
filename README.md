# Tenancy

The objective of this repo is to capture tenancy enforcement in a variety of ways. When tenancy is enforced on a table, no query should *ever* be able
to be made without the tenancy key present. Any attempt to do so will be an error.

In Ruby, the MultiTenant gem will add the tenancy key that you specify. This works due to the single-threaded nature of a request---it can just put the
tenancy key in the `Thread.current`. Due to the multi-process / multi-stack design of most Elixir apps, this project will not attempt to capture automatic
addition of a tenancy key to a query.

## Inserts

Inserts aren't really an issue because any models that have `tenant_id` will have it required at the database / schema levels. It's not possible to insert
without tenancy in that case.

## Solution 1 - `prepare_query` Callback

Use the new `prepare_query` callback to check tenancy on all DB queries. Some database queries are not supported for `prepare_query`, like `insert_all`.
Preferably, these functions can be disabled on the Repo.

## Solution 2 - Repo Proxy

Wrap the Ecto.Repo in a new Repo that acts as a proxy. Any query would be checked for the tenancy key.
