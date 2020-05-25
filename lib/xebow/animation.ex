defmodule Xebow.Animation do
  @moduledoc """
  Provides a data structure and functions to define a Xebow animation.

  There are currently two distinct ways to define an animation.

  You may define an animation with a predefined `:frames` field. Each frame will advance every `:delay_ms` milliseconds.
  These animations should use the `Xebow.Animation.{OneShot,Loop}` `:type`. See the moduledocs of those modules for
  examples.

  Alternatively, you may have a more dynamic animation which generates frames based on the current `:tick` of the
  animation. See `Xebow.Animation.{CycleAll, CycleLeftToRight, Pinwheel} for examples.
  """

  alias __MODULE__
  alias Xebow.{AnimationFrame}

  defmacro __using__(_) do
    quote do
      alias Xebow.Animation

      @behaviour Animation
    end
  end

  @callback next_frame(animation :: Animation.t()) :: AnimationFrame.t()

  @type t :: %__MODULE__{
          type: animation_type,
          tick: non_neg_integer,
          speed: non_neg_integer,
          loop: non_neg_integer | -1,
          delay_ms: non_neg_integer,
          frames: list(AnimationFrame.t()),
          next_frame: AnimationFrame.t() | nil
        }
  defstruct [:type, :tick, :speed, :delay_ms, :loop, :next_frame, :frames]

  @type animation_type ::
          __MODULE__.CycleAll
          | __MODULE__.CycleLeftToRight
          | __MODULE__.Pinwheel
          | __MODULE__.Static

  @doc """
  Returns a list of the available types of animations.
  """
  @spec types :: list(animation_type)
  def types do
    [
      __MODULE__.CycleAll,
      __MODULE__.CycleLeftToRight,
      __MODULE__.Pinwheel
    ]
  end

  @type animation_opt ::
          {:type, animation_type}
          | {:frames, list}
          | {:tick, non_neg_integer}
          | {:speed, non_neg_integer}
          | {:delay_ms, non_neg_integer}
          | {:loop, non_neg_integer | -1}

  @type animation_opts :: list(animation_opt)

  @spec new(opts :: animation_opts) :: Animation.t()
  def new(opts) do
    animation_type = Keyword.fetch!(opts, :type)
    frames = Keyword.get(opts, :frames, [])

    %Animation{
      type: animation_type,
      tick: opts[:tick] || 0,
      speed: opts[:speed] || 100,
      delay_ms: opts[:delay_ms] || 17,
      loop: opts[:loop] || -1,
      frames: frames,
      next_frame: List.first(frames)
    }
  end

  @doc """
  Updates the state of an animation with the next tick of animation.
  """
  @spec next_frame(animation :: Animation.t()) :: Animation.t()
  def next_frame(animation) do
    next_frame = animation.type.next_frame(animation)
    %Animation{animation | next_frame: next_frame, tick: animation.tick + 1}
  end

  @doc """
  Returns the frame count of a given animation,

  Note: this function returns -1 for dynamic animations.
  """
  @spec frame_count(animation :: Animation.t()) :: non_neg_integer | -1
  def frame_count(%{loop: -1}), do: -1

  def frame_count(animation), do: length(animation.frames) * animation.loop

  @doc """
  Returns the expected duration of a given animation.

  Note: this function returns -1 for dynamic animations.
  """
  @spec duration(animation :: Animation.t()) :: non_neg_integer | -1
  def duration(%{loop: -1}), do: -1

  def duration(animation), do: frame_count(animation) * animation.delay_ms
end
