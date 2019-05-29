library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
USE std.textio.ALL;
--use work.sp_vision_test_pkg.all;

entity top_meanComplex_tb is
end entity top_meanComplex_tb;

architecture RTL of top_meanComplex_tb is
	signal reset : std_logic;
	CONSTANT HALF_PERIODE : time := 5.0 ns;  -- Half clock period
	signal clk : std_logic;

	constant DATA_SIZE : natural := 16;
	signal data_en_s, data_en_o : std_logic;
	signal data_i_s, data_q_s : std_logic_vector(DATA_SIZE-1 downto 0);
	signal data_i_o, data_q_o : std_logic_vector(DATA_SIZE-1 downto 0);
begin

	moy_inst: Entity work.meanComplex
	generic map (format => "signed",
		nb_accum => 8, shift => 3,
		OUTPUT_DATA_SIZE => DATA_SIZE,
		INPUT_DATA_SIZE => DATA_SIZE)
	port map (rst_i => reset, clk_i => clk,
		data_i_i => data_i_s, data_q_i => data_q_s,
		data_en_i => data_en_s,
		data_i_o => data_i_o, data_q_o => data_q_o,
		data_en_o => data_en_o);

	atan_propagation : process(clk, reset)
	begin
		if (reset = '1') then
			data_i_s <= (others => '0');
			data_q_s <= (others => '0');
			data_en_s <= '0';
		elsif rising_edge(clk) then
			data_i_s <= std_logic_vector(unsigned(data_i_s) +1);
			data_q_s <= std_logic_vector(unsigned(data_q_s) +1);
			data_en_s <= '1';
		end if;
	end process; 

    stimulis : process
    begin
	reset <= '1';
	wait until rising_edge(clk);
	reset <= '1';
	wait until rising_edge(clk);
	wait until rising_edge(clk);
	wait until rising_edge(clk);
	reset <= '0';
    wait for 10 ns;
	report "fin de la lecture de la LUT" severity note;
	report "fin de la lecture des data" severity note;
    wait for 10 us;
	report "plop1" severity note;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
    wait for 10 us;
--   wait for 10 us;
--    wait for 10 us;
--    wait for 10 us;
--    wait for 10 us;
--    wait for 10 us;
--    wait for 10 us;
--	wait for 1 ms;
    assert false report "End of test" severity error;
    end process stimulis;
    
    clockp : process
    begin
        clk <= '1';
        wait for HALF_PERIODE;
        clk <= '0';
        wait for HALF_PERIODE;
    end process clockp;
    
end architecture RTL;
