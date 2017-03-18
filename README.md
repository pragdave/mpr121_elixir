# MPR121 Interface for Elixir

  ** DON'T USE — Still under development **

  This module drives a MPR121 12-channel touch sensor via the I2C
  interface provided by Elixir/ALE.

  The interface sits on an i2c bus, and has an address that can be 
  set with a soldered jumper.

  You initialize the interface using `start_link()`, passing in the
  name of the bus (typically `i2c-1`. You can also pass the address of
  the MPR121 (which defaults to 0x5a) and options.

  ~~~ elixir
  { :ok, device } = Mpr121.start_link("i2c-1")
  
  bits = Mpr121.touch_state_all(device)  # => 12 bits, one per touch channel
  
  if Mpr121.is_touched?(device, 10) do
    # executes if pin 10 (numbered from zero) is currently touched
  end
  ~~~


  This module cannot run without the I2C module from Elixir/ALE.
  Unfortunately, ALE can only be built on Linux boxes. To partially
  mitigate this, we include a stubbed out version of the I2C module at
  the end of `lib/mpr121.ex`. This stub is only compiled into your
  application in `:dev` and `:test` environments. In `:prod` mix will
  automatically use the real thing. This means you'll need to set the
  env to :prod and do a `mix do deps.get, deps.compile` if you plan to
  run this on your development machine.

  If running with Nerves, this should all just work out.


  
  Based on the Python library, which is:
  
  >  Copyright (c) 2014 Adafruit Industries
  >  Author: Tony DiCola
  >  
  >  Permission is hereby granted, free of charge, to any person obtaining a copy
  >  of this software and associated documentation files (the "Software"), to deal
  >  in the Software without restriction, including without limitation the rights
  >  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  >  copies of the Software, and to permit persons to whom the Software is
  >  furnished to do so, subject to the following conditions:
  >  
  >  The above copyright notice and this permission notice shall be included in
  >  all copies or substantial portions of the Software.
  >  
  >  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  >  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  >  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  >  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  >  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  >  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  >  THE SOFTWARE.

## Installation

```elixir
@deps [
  ...
  mpr121: "~> 0.1.0",
]
```


