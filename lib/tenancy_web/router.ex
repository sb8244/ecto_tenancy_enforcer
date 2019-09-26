defmodule TenancyWeb.Router do
  use TenancyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TenancyWeb do
    pipe_through :api
  end
end
