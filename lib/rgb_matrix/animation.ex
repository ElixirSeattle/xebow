defmodule RGBMatrix.Animation do
  @moduledoc """
  Provides the behaviour and interface for working with animations.
  """

  alias Layout.LED
  alias __MODULE__.Config

  defstruct [:type, :config, :state]

  @type t :: %__MODULE__{
          type: type,
          config: Config.t(),
          state: any
        }
  @type animation_state :: any
  @type render_in :: non_neg_integer() | :never | :ignore
  @type type ::
          __MODULE__.CycleAll
          | __MODULE__.HueWave
          | __MODULE__.Pinwheel
          | __MODULE__.RandomSolid
          | __MODULE__.RandomKeypresses
          | __MODULE__.SolidColor
          | __MODULE__.Breathing
          | __MODULE__.SolidReactive
          | __MODULE__.Simon

  @callback new(leds :: [LED.t()], config :: Config.t()) :: animation_state
  @callback render(state :: animation_state, config :: Config.t()) ::
              {render_in, [RGBMatrix.any_color_model()], animation_state}
  @callback interact(state :: animation_state, config :: Config.t(), led :: LED.t()) ::
              {render_in, animation_state}

  @doc """
  Returns a list of the available types of animations.
  """
  @spec types :: [type]
  def types do
    [
      __MODULE__.CycleAll,
      __MODULE__.HueWave,
      __MODULE__.Pinwheel,
      __MODULE__.RandomSolid,
      __MODULE__.RandomKeypresses,
      __MODULE__.SolidColor,
      __MODULE__.Breathing,
      __MODULE__.SolidReactive,
      __MODULE__.Simon
    ]
  end

  @doc """
  Returns a human-readable name for an animation type.
  """
  @spec type_name(animation_type :: type) :: String.t()
  def type_name(animation_type) do
    animation_type
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> String.replace(~r/([A-Z])/, " \\1")
    |> String.trim_leading()
  end

  @doc """
  Returns an animation's initial state.
  """
  @spec new(animation_type :: type, leds :: [LED.t()]) :: t
  def new(animation_type, leds) do
    config_module = Module.concat([animation_type, "Config"])
    animation_config = config_module.new()
    animation_state = animation_type.new(leds, animation_config)

    %__MODULE__{
      type: animation_type,
      config: animation_config,
      state: animation_state
    }
  end

  @doc """
  Returns the next state of an animation based on its current state.
  """
  @spec render(animation :: t) :: {render_in, RGBMatrix.Engine.frame(), t}
  def render(animation) do
    {render_in, colors, animation_state} =
      animation.type.render(animation.state, animation.config)

    {render_in, colors, %{animation | state: animation_state}}
  end

  @doc """
  Sends an interaction event to an animation.
  """
  @spec interact(animation :: t, led :: LED.t()) :: {render_in, t}
  def interact(animation, led) do
    {render_in, animation_state} = animation.type.interact(animation.state, animation.config, led)
    {render_in, %{animation | state: animation_state}}
  end

  @doc """
  Gets the current configuration and the configuration schema from an animation.
  """
  @spec get_config(animation :: t) :: {Config.t(), Config.schema()}
  def get_config(animation) do
    %config_module{} = config = animation.config
    schema = config_module.schema()

    {config, schema}
  end

  @doc """
  Updates the configuration of an animation and returns the updated animation.
  """
  @spec update_config(animation :: t, params :: Config.update_params()) :: t
  def update_config(animation, params) do
    %config_module{} = config = animation.config
    config = config_module.update(config, params)

    %{animation | config: config}
  end

  @doc """
  Defines a configuration field for an animation.

  Example:
      field :speed, :integer,
        default: 4,
        min: 0,
        max: 32,
        doc: [
          name: "Speed",
          description: \"""
          Controls the speed at which the wave moves across the matrix.
          \"""
        ]
  """
  defmacro field(name, type, opts \\ []) when is_list(opts) do
    field_type =
      Config.field_types()
      |> Map.get(type)

    opts =
      Enum.map(opts, fn {key, value} ->
        {key, Macro.expand(value, __CALLER__)}
      end)

    quote do
      @fields {
        unquote(name),
        struct!(unquote(field_type), unquote(opts))
      }
    end
  end

  defmacro __using__(_) do
    animation_module = __MODULE__

    quote do
      @behaviour unquote(animation_module)

      import unquote(animation_module)
      import unquote(animation_module).Config

      Module.register_attribute(__MODULE__, :fields,
        accumulate: true,
        persist: false
      )

      @impl true
      def interact(state, _config, _led) do
        {:ignore, state}
      end

      defoverridable interact: 3

      @before_compile unquote(animation_module).Config
    end
  end
end
