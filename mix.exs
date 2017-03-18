defmodule Mpr121.Mixfile do
  use Mix.Project

  @deps [
    { :elixir_ale, "~> 0.5", only: :prod }
  ]
  
  def project do
    [
      app: :mpr121,
      version: "0.1.0",
      deps: @deps,
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

end
