-------------------------------------------------------------------------------
-- Tang Nano 9K top level module for vectrex
-- by Ryo Mukai (github.com/ryomuk)
-- 2022/12/09
-- 
-- modified from vectrex_de10_lite.vhd by Dar
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--  
-- Vectrex releases
--
-- Release 0.1 - 05/05/2018 - Dar
--		add sp0256-al2 VHDL speech simulation
--    add speakjet interface (speech IC)
--
-- Release 0.0 - 10/02/2018 - Dar
--		initial release
--
---------------------------------------------------------------------------------
-- Use vectrex_de10_lite.sdc to compile (Timequest constraints)
-- /!\
-- Don't forget to set device configuration mode with memory initialization 
--  (Assignments/Device/Pin options/Configuration mode)
---------------------------------------------------------------------------------
-- TODO :
--   sligt tune of characters drawings (too wide)
--   tune hblank to avoid persistance artifact on first 4 pixels of a line
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input @gpio pins 35/34 (beware voltage translation/protection) 
--  Audio pwm output   @gpio pins 1/3 (beware voltage translation/protection) 
--
--  Uses 1 pll for 25/24MHz and 12.5/12MHz generation from 50MHz
--
--  Horizontal/vertical display selection at compilation 
--  3 or no intensity level selection at compilation
--
--  No external ram
--  FPGA ram usage as low as :
--
--		  336.000b ( 42Ko) without   cartridge, vertical display,   no intensity level (minestrom)
--		  402.000b ( 50Ko) with  8Ko cartridge, vertical display,   no intensity level
--	 	  599.000b ( 74ko) with 32Ko cartridge, vertical display,   no intensity level
--	 	  664.000b ( 82ko) with  8Ko cartridge, horizontal display, no intensity level
--		1.188.000b (146ko) with  8Ko cartridge, horizontal display, 3 intensity level

--  Tested cartridge:
--
--		berzerk          ( 4ko)
--		ripoff           ( 4ko)
--		scramble         ( 4ko)
--		spacewar         ( 4ko)
--		startrek         ( 4ko)
--		pole position    ( 8ko)
--		spike            ( 8ko)
--		webwars          ( 8ko)
--		frogger          (16Ko)
--		vecmania1        (32ko)
--		war of the robot (21ko)
--
-- Board key :
--   0 : reset game
--
-- Keyboard players inputs :
--
--   F3 : button
--   F2 : button
--   F1 : button 
--   SPACE       : button
--   RIGHT arrow : joystick right
--   LEFT  arrow : joystick  left
--   UP    arrow : joystick  up 
--   DOWN  arrow : joystick  down
--
-- Other details : see vectrex.vhd
-- For USB inputs and SGT5000 audio output see my other project: xevious_de10_lite
---------------------------------------------------------------------------------
-- Use tool\vectrex_unzip\make_vectrex_proms.bat to build vhdl rom files
--
--make_vhdl_prom 	exec_rom.bin vectrex_exec_prom.vhd (always needed)
--
--make_vhdl_prom 	scramble.bin vectrex_scramble_prom.vhd
--make_vhdl_prom 	berzerk.bin vectrex_berzerk_prom.vhd
--make_vhdl_prom 	frogger.bin vectrex_frogger_prom.vhd
--make_vhdl_prom 	spacewar.bin vectrex_spacewar_prom.vhd
--make_vhdl_prom 	polepos.bin vectrex_polepos_prom.vhd
--make_vhdl_prom 	ripoff.bin vectrex_ripoff_prom.vhd
--make_vhdl_prom 	spike.bin vectrex_spike_prom.vhd
--make_vhdl_prom 	startrek.bin vectrex_startrek_prom.vhd
--make_vhdl_prom 	vecmania1.bin vectrex_vecmania1_prom.vhd
--make_vhdl_prom 	webwars.bin vectrex_webwars_prom.vhd
--make_vhdl_prom 	wotr.bin vectrex_wotr_prom.vhd
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
--use work.usb_report_pkg.all;

entity vectrex_tn9k is
port(
  clk       : in std_logic;
  led       : out std_logic_vector(5 downto 0);
  sw_S1     : in std_logic;
  sw_S2     : in std_logic;

  gpin      : in  std_logic_vector(7 downto 0);
  gpout     : out std_logic_vector(7 downto 0)
);
end vectrex_tn9k;

architecture struct of vectrex_tn9k is

 signal clock_12p5 : std_logic;
 signal clock_25   : std_logic;
 signal reset      : std_logic;

 constant CLOCK_FREQ : integer := 27E6;
 signal counter_clk: std_logic_vector(25 downto 0);
 signal clock_4hz : std_logic;
 
-- signal max3421e_clk : std_logic;
 signal r         : std_logic_vector(3 downto 0);
 signal g         : std_logic_vector(3 downto 0);
 signal b         : std_logic_vector(3 downto 0);
 signal csync     : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;
 signal blankn    : std_logic;
 
 signal vga_r     : std_logic;
 signal vga_g     : std_logic;
 signal vga_b     : std_logic;
 signal vga_hs    : std_logic;
 signal vga_vs    : std_logic;

 signal audio           : std_logic_vector( 9 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 alias reset_n         : std_logic is sw_S1;
 signal pwm_audio_out_l : std_logic;
 signal pwm_audio_out_r : std_logic;

 signal pot_x : signed(7 downto 0);
 signal pot_y : signed(7 downto 0);
 signal pot_speed_cnt : std_logic_vector(15 downto 0);
 
 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

reset <= not reset_n;
clock_25 <= clk;

process (reset, clock_25)
begin
  if reset='1' then
    clock_12p5 <= '0';
  else 
    if rising_edge(clock_25) then
      clock_12p5  <= not clock_12p5;
    end if;
  end if;
end process;

for_debug:
process(reset, clk)
begin
  if reset = '1' then
    clock_4hz <= '0';
    counter_clk <= (others => '0');
  else
    if rising_edge(clk) then
      if counter_clk = CLOCK_FREQ/8 then
        counter_clk <= (others => '0');
        clock_4hz <= not clock_4hz;
--        led(0) <= clock_4hz;
--        led(4 downto 0) <= not dbg_cpu_addr(4 downto 0);
        led(5 downto 0) <= not dbg_cpu_addr(9 downto 4);
      else
        counter_clk <= counter_clk + 1;
      end if;
    end if;
  end if;
end process for_debug;

-- vectrex
vectrex : entity work.vectrex
port map(
 clock_24  => clock_25,  
 clock_12  => clock_12p5,
 reset     => reset,
 
 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,
 audio_out    => audio,
  
 rt_1      => not gpin(7),
 lf_1      => not gpin(6),
 dn_1      => not gpin(5),
 up_1      => not gpin(4),
 pot_x_1   => pot_x,
 pot_y_1   => pot_y,

 rt_2      => '0',
 lf_2      => '0',
 dn_2      => '0',
 up_2      => '0',
 pot_x_2   => pot_x,
 pot_y_2   => pot_y,

-- leds       => open,
 
 speakjet_cmd => open,
 speakjet_rdy => '0',
 speakjet_pwm => '0',
 
 external_speech_mode => "00",  -- "00" : no speech synth. "01" : sp0256. "10" : speakjet.  

 dbg_cpu_addr => dbg_cpu_addr,
 sw => "00000000"
);

pot_x <= "01111111" when gpin(0) = '1' and gpin(2) = '0' else
         "10000000" when gpin(0) = '0' and gpin(2) = '1' else
         "00000000";
pot_y <= "01111111" when gpin(1) = '0' and gpin(3) = '1' else
         "10000000" when gpin(1) = '1' and gpin(3) = '0' else
         "00000000";


vga_r <= (r(3) or r(2) or r(1) or r(0)) when blankn = '1' else '0';
vga_g <= (g(3) or g(2) or g(1) or g(0)) when blankn = '1' else '0';
vga_b <= (b(3) or b(2) or b(1) or b(0)) when blankn = '1' else '0';

-- synchro composite/ synchro horizontale
--vga_hs <= csync;
vga_hs <= hsync;
-- commutation rapide / synchro verticale
--vga_vs <= '1';
vga_vs <= vsync;

-- gpout(0) <= vga_b;
-- gpout(1) <= vga_g;
gpout(0) <= vga_b or vga_r; -- force red frame_line to white
gpout(1) <= vga_g or vga_r; -- force red frame_line to white
gpout(2) <= vga_r;
gpout(3) <= vga_vs;
gpout(4) <= vga_hs;
gpout(5) <= pwm_audio_out_l;
gpout(6) <= pwm_audio_out_r;
gpout(7) <= pwm_audio_out_l or pwm_audio_out_r;

--led(5 downto 0) <= not gpin(5 downto 0);

--sound_string <= "00" & audio & "000" & "00" & audio & "000";

-- get scancode from keyboard

--
--sample_data <= "00" & audio & "000" & "00" & audio & "000";				

-- Clock 1us for ym_8910

--p_clk_1us_p : process(max10_clk1_50)
--begin
--	if rising_edge(max10_clk1_50) then
--		if cnt_1us = 0 then
--			cnt_1us  <= 49;
--			clk_1us  <= '1'; 
--		else
--			cnt_1us  <= cnt_1us - 1;
--			clk_1us <= '0'; 
--		end if;
--	end if;	
--end process;	 

-- sgtl5000 (teensy audio shield on top of usb host shield)

--e_sgtl5000 : entity work.sgtl5000_dac
--port map(
-- clock_18   => clock_18,
-- reset      => reset,
-- i2c_clock  => clk_1us,  
--
-- sample_data  => sample_data,
-- 
-- i2c_sda   => arduino_io(0), -- i2c_sda, 
-- i2c_scl   => arduino_io(1), -- i2c_scl, 
--
-- tx_data   => arduino_io(2), -- sgtl5000 tx
-- mclk      => arduino_io(4), -- sgtl5000 mclk 
-- 
-- lrclk     => arduino_io(3), -- sgtl5000 lrclk
-- bclk      => arduino_io(6), -- sgtl5000 bclk   
-- 
-- -- debug
-- hex0_di   => open, -- hex0_di,
-- hex1_di   => open, -- hex1_di,
-- hex2_di   => open, -- hex2_di,
-- hex3_di   => open, -- hex3_di,
-- 
-- sw => sw(7 downto 0)
--);

-- pwm sound output

process(clock_12p5)  -- use same clock as sound process
begin
  if rising_edge(clock_12p5) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio&"00"));
  end if;
end process;

pwm_audio_out_l <= pwm_accumulator(12);
pwm_audio_out_r <= pwm_accumulator(12); 

-- speakjet pwm direct to audio pwm 
--pwm_audio_out_l <= arduino_io(2);
--pwm_audio_out_r <= arduino_io(2);


end struct;
