defmodule Mpr121 do

  require Logger

  alias ElixirALE.I2C
  
  @moduledoc File.read!("README.md")

  @type register     :: 0..127
  @type pin          :: 0..11
  @type ten_bits     :: 0..0x3ff
  @type sixteen_bits :: 0..0xffff
  @type bus_name     :: String.t
  
  # Register addresses
  
  @baseline_0      0x1E
  @config1         0x5C
  @config2         0x5D
  @debounce        0x5B
  @ecr             0x5E
  @fdlf            0x32
  @fdlr            0x2E
  @fdlt            0x35
  @filtdata_0l     0x04
  @mhdf            0x2F
  @mhdr            0x2B
  @nclf            0x31
  @nclr            0x2D
  @nclt            0x34
  @nhdf            0x30
  @nhdr            0x2C
  @nhdt            0x33
  @releaseth_0     0x42
  @softreset       0x80
  @touchstatus_l   0x00
  @touchth_0       0x41

  # @autoconfig0     0x7B
  # @autoconfig1     0x7C
  # @chargecurr_0    0x5F
  # @chargetime_1    0x6C
  # @filtdata_0H     0x05
  # @gpioclr         0x79
  # @gpiodir         0x76
  # @gpioen          0x77
  # @gpioset         0x78
  # @gpiotoggle      0x7A
  # @lowlimit        0x7E
  # @targetlimit     0x7F
  # @touchstatus_H   0x01
  # @uplimit         0x7D

  @i2caddr_default  0x5a

  @combined_flag_path "/sys/module/i2c_bcm2708/parameters/combined"
  @combined_flag_yes  "Y"
  @combined_flag_no   "N"
  

  # @max_i2c_retries 5

  # this is the configuration we set on reset.
  @default_config  [
    # Configure baseline filtering control registers.
    { @mhdr, 0x01 },
    { @nhdr, 0x01 },
    { @nclr, 0x0E },
    { @fdlr, 0x00 },
    { @mhdf, 0x01 },
    { @nhdf, 0x05 },
    { @nclf, 0x01 },
    { @fdlf, 0x00 },
    { @nhdt, 0x00 },
    { @nclt, 0x00 },
    { @fdlt, 0x00 },
    
    # Set other configuration registers.
    { @debounce, 0x00 },
    { @config1,  0x10 }, # default, 16uA charge current
    { @config2,  0x20 }, # 0.5uS encoding, 1ms period
    
    # Enable all electrodes. Start with first 5 bits of baseline tracking
    { @ecr,      0x8F }
  ]
    
  

  defstruct i2c: nil, options: []


  #######
  # API #
  #######

  @doc """
  Start up an instance of the Mpr121 interface. 

      Mpr121.start_link(bus, address \\ 0x5a, options \\ [])

  * `bus` is the name of the i2c device to use (typically "i2c-1").

  * `address` is the address of your Mpr121 controller on the bus.
    This can be set on the Adafruit card by soldering a strap. The
    default (unstrapped) address is `0x5a`.

  * `options` is currently unused.

  Returns `{ :ok, i2c }`, where `i2c` is the token to be passed to
  subsequent api calls. (OK, it's the pid of this server, but that's
  just a leaky abstraction.)
  """

  @spec start_link(bus_name(), byte(), list( {atom(), any() })) :: { :ok, pid() }
  
  def start_link(bus, address \\ @i2caddr_default, options \\ []) do
    GenServer.start(__MODULE__, {bus, address, options})
  end

  @doc """
  Reset the device to a known state. Any thresholds you may have previously
  changed will be reset. A reset is automatically performed when
  you call `start_link` on this module.
  """

  @spec reset(pid()) :: any()
  
  def reset(i2c) do
    GenServer.call(i2c, { :reset })
  end
  
  @doc """
  Return touch state of all pins as a 12-bit value where each bit 
  represents a pin, with a value of 1 being touched and 0 not being touched.
  """

  @spec touch_state_all(pid()) :: 0..0x0fff
  
  def touch_state_all(i2c) do
    GenServer.call(i2c, { :touch_state_all })
  end
    
  @doc """
  Return `true` if the specified pin is being touched, otherwise returns
  `false`.
  """

  @spec is_touched?(pid, pin) :: boolean()
  
  def is_touched?(i2c, pin)
  when pin in 0..11 do
    use Bitwise
    (touch_state_all(i2c) &&& (1 <<< pin)) != 0
  end

  @doc """
  Set the touch and release threshold for all inputs to the provided
  values.  Both touch and release should be a value between 0 to 255
  (inclusive). Returns noting meaningful
  """

  @spec set_thresholds(pid(), byte(), byte()) :: any()
  
  def set_thresholds(i2c, touch, release)
  when touch in 0..255 and release in 0..255 do
    GenServer.call(i2c, { :set_thresholds, touch, release })
  end

  @doc """
  Return filtered data register value for the provided pin (0-11).
  Useful for debugging.
  """

  @spec filtered_data(pid(), pin()) :: sixteen_bits()

  def filtered_data(i2c, pin)
  when pin in 0..11 do
    GenServer.call(i2c, { :filtered_data, pin })
  end
    
  @doc """
  Return baseline data register value for the provided pin (0-11).
  Useful for debugging.
  """

  @spec baseline_data(pid(), pin()) :: ten_bits()
  
  def baseline_data(i2c, pin)
  when pin in 0..11 do
    GenServer.call(i2c, { :baseline_data, pin })
  end
    

  ##################
  # Implementation #
  ##################

  @doc false
  def init({bus, address, options}) do
    { :ok, i2c } = I2C.start_link(bus, address)
    state = %__MODULE__{i2c: i2c, options: options}
    Process.send_after(self(), :reset, 0)
    { :ok, state }
  end

  @doc false
  def handle_info(:reset, state = %{ i2c: i2c }) do
    do_reset_mpr121(i2c)
    { :noreply, state }
  end

  @doc false
  def handle_call({ :reset }, state = %{ i2c: i2c }) do
    do_reset_mpr121(i2c)
    { :reply, true, state }
  end
  
  
  @doc false
  def handle_call({ :set_thresholds, touch, release }, _, state = %{ i2c: i2c }) do
    do_set_thresholds(i2c, touch, release)
    { :reply, true, state }
  end

  @doc false
  def handle_call({ :touch_state_all }, _, state = %{ i2c: i2c }) do
    use Bitwise
    result = do_retry_wr(i2c, << @touchstatus_l >>, 2) &&& 0x0FFF
    { :reply, result, state }
  end
    
  @doc false
  def handle_call({ :filtered_data, pin }, _, state = %{ i2c: i2c }) do
    result = do_retry_wr(i2c, << @filtdata_0l + pin*2 >>, 2)
    { :reply, result, state }
  end
    
  @doc false
  def handle_call({ :baseline_data, pin }, _, state = %{ i2c: i2c }) do
    use Bitwise
    result = do_retry_wr(i2c, << @baseline_0 + pin >>, 1) <<< 2
    { :reply, result, state }
  end
    
  ###########
  # Helpers #
  ###########

  @spec do_reset_mpr121(pid()) :: any()
  defp do_reset_mpr121(i2c) do
    # This may well mess up other i2c bus users, but there doesn't seem to
    # be a way around it

    do_set_combined_flag(true)

    # device reset
    do_retry_w(i2c, << @softreset, 0x63 >>)

    # Set electrode configuration to default values.
    do_retry_w(i2c, << @ecr, 0x00 >>)

    # Check CDT, SFI, ESI configuration is at default values.
    status = do_retry_wr(i2c, <<@config2>>, 1)
    if status != 0x24 do
      raise("config2 values incorrect after reset…\n" <>
        "\tExpected 0x24, got 0x#{Integer.to_string(status, 16)}\n" <>
        "This might be because I'm talking to the wrong device, or because\n" <>
        "the i2c controller is not in repeated start mode. If the latter\n" <>
        "case, may your God have mercy on you.")
      
    end

    # Set threshold for touch and release to default values.
    do_set_thresholds(i2c, 12, 6)

    do_set_registers(i2c, @default_config)
  end


  @spec dump([ byte() ]) :: binary()
  def dump(data) do
    for(<< byte <- data >>, do: "0x#{Integer.to_string(byte, 16)}")
    |> Enum.join(", ")
  end

  # write a binary to the device
  @spec do_retry_w( pid(), binary() ) :: nil
  defp do_retry_w(i2c, data) do
    I2C.write(i2c, data)
    nil
  end

  # atomic write/read. Reads `input_size` bytes, and then builds the
  # result into an integer

  @spec do_retry_wr(pid(), binary(), pos_integer()) :: pos_integer()
  defp do_retry_wr(i2c, data, input_size) do
    result = I2C.write_read(i2c, data, input_size)
             |> :binary.decode_unsigned(:little)
    result
  end

  @spec do_set_registers( pid(), [ { register(), byte() } ]) :: nil
  defp do_set_registers(i2c, values) do
    for { register, content } <- values do
      do_retry_w(i2c, << register, content >>)
    end
    nil
  end    

  @spec do_set_thresholds( pid(), byte(), byte()) :: nil
  defp do_set_thresholds(i2c, touch, release) do
    for i <- 0..11 do
      do_retry_w(i2c, << @touchth_0   + 2*i, touch >>)
      do_retry_w(i2c, << @releaseth_0 + 2*i, release >>)
    end
    nil
  end
  
  @spec do_set_combined_flag(flag :: as_boolean(any)) :: any()
  def do_set_combined_flag(flag) do
    flag_char = if flag, do: @combined_flag_yes, else: @combined_flag_no
    File.chmod!(@combined_flag_path, 0o666)
    File.write!(@combined_flag_path, flag_char)
  end
end

if Mix.env != :prod do
  defmodule ElixirALE.I2C do

    import Mpr121, only: [ dump: 1]
    require Logger
    
    def start_link(a, b) do
      Logger.info("mock i2c.start_link(#{inspect a}, #{inspect b})")
      { :ok, :pid }
    end

    def write(:pid, data) do
      Logger.info("Writing #{dump data}")
    end

    def write_read(:pid, data, len) do
      Logger.info("write_read #{dump data}")
      result = 0x24..(0x24+len-1) |> Enum.into([])
      Logger.info("\t\t=> #{inspect result}")
      result
    end
  end
end
