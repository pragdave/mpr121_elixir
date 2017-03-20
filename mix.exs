defmodule Mpr121.Mixfile do
  use Mix.Project

  @version "0.1.0"
  
  @deps [
    { :elixir_ale, "~> 0.5", only: :prod },
  ]

  ############################################################
  
  def project do
    in_production = Mix.env == :prod
    [
      app:     :mpr121,
      version: @version,
      deps:    @deps,
      build_embedded:  in_production,
      start_permanent: in_production,
    ]
  end

  def application do
    [
      extra_applications: [
        :logger,
      ],
    ]
  end

end
