library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
USE std.textio.ALL;

entity top_enable_tb is
end entity top_enable_tb;

architecture RTL of top_enable_tb is
	function to_string(sv: Std_Logic_Vector) return string is
		use Std.TextIO.all;
		variable bv: bit_vector(sv'range) := to_bitvector(sv);
		variable lp: line;
	begin
		write(lp, bv);
		return lp.all;
	end;
	file final_result_file: text open write_mode is "./result.txt";

	signal reset : std_logic;
   CONSTANT HALF_PERIODE : time := 5.0 ns;  -- Half clock period
   	signal clk : std_logic;
	constant DECIMATE_FACTOR : natural := 10;
	constant NB_COEFF : natural := 128;
	signal tick_s : std_logic;

	constant DATA_SIZE : natural := 16;
	constant DATA_OUT_SIZE : natural := 32;
	constant ADDR_SIZE : natural := 10;

	-- new
	constant COEFF_SIZE : natural := 16;
	constant COEFF_ADDR_SZ : natural := natural(ceil(log2(real(NB_COEFF))));
	-- coeff configuration
	signal start_read_coeff, end_read_coeff : std_logic;
	signal coeff_addr_s : std_logic_vector(COEFF_ADDR_SZ-1 downto 0);
	signal coeff_addr_next_s : unsigned(COEFF_ADDR_SZ-1 downto 0);
	signal coeff_val_s : std_logic_vector(COEFF_SIZE-1 downto 0);
	signal coeff_data_s : unsigned(COEFF_SIZE-1 downto 0);
	signal coeff_en_s : std_logic;
	-- read data
	signal read_data_val_s : std_logic_vector(DATA_SIZE-1 downto 0);
	signal read_data_addr_s : std_logic_vector(ADDR_SIZE-1 downto 0);
	signal read_data_en_s, end_read2_s : std_logic;
	signal start_read_s : std_logic;
	-- gen data
	signal prop_data_addr_s : std_logic_vector(ADDR_SIZE-1 downto 0);
	signal prop_data_addr_nat_s: natural range 0 to 2**ADDR_SIZE-1;
	signal data_s, data_q_s : std_logic_vector(DATA_SIZE-1 downto 0);
	signal data_en_s : std_logic;

	-- data gen
	signal start_prod_s : std_logic;


	-- output data
	signal data_out_en_s : std_logic;
	signal data_out_i_s, data_out_q_s : std_logic_vector(DATA_OUT_SIZE-1 downto 0);

	-- res cpt
	constant MAX_RES_CPT : natural := 193;
	signal res_cpt_s : natural range 0 to MAX_RES_CPT-1;
	signal end_simu_s : std_logic;
begin
	process(clk) begin
		if rising_edge(clk) then
			if reset = '1' then
				tick_s <= '0';
			else
				if (start_prod_s = '1') then
					tick_s <= not tick_s;
					--tick_s <= '1';
				else
					tick_s <= '0';
				end if;
			end if;
		end if;
	end process;

	fir16 : Entity work.firComplex_top
	generic map (
		DECIMATE_FACTOR => DECIMATE_FACTOR,
		NB_COEFF => NB_COEFF,
		COEFF_SIZE => COEFF_SIZE,
		COEFF_ADDR_SZ => COEFF_ADDR_SZ,
		DATA_OUT_SIZE => DATA_OUT_SIZE 
	)
	port map
	(
		reset	=> reset,
		clk => clk,
		clk_axi => clk,
		-- coeff conf
		wr_coeff_en_i => coeff_en_s,
		wr_coeff_addr_i => coeff_addr_s,
		wr_coeff_val_i => coeff_val_s,
		-- input data
		data_i_i => data_s,
		data_q_i => data_q_s,
		data_en_i => data_en_s,
		-- for the next component
		data_i_o => data_out_i_s,
		data_q_o => data_out_q_s,
		data_en_o => data_out_en_s
	);

	--data_q_s <= std_logic_vector(signed(data_s)+10);
	data_q_s <= data_s;

	process(clk) begin
		if rising_edge(clk) then
			end_read_coeff <= '0';
			coeff_en_s <= '0';
			if reset = '1' then
				coeff_addr_next_s <= (others => '0');
				coeff_addr_s <= (others => '0');
				coeff_data_s <= to_unsigned(128, COEFF_SIZE);
				coeff_val_s <= (others => '0');
			else
				coeff_addr_next_s <= coeff_addr_next_s;
				coeff_addr_s <= coeff_addr_s;
				coeff_val_s <= coeff_val_s;
				if start_read_coeff = '1' then
					if unsigned(coeff_addr_s) = 127 then
						end_read_coeff <= '1';
					else
						coeff_en_s <= '1';
						coeff_addr_s <= std_logic_vector(coeff_addr_next_s);
						coeff_addr_next_s <= coeff_addr_next_s + 1;
						coeff_val_s <= std_logic_vector(coeff_data_s);
						coeff_data_s <= coeff_data_s + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	store_result : process(clk, reset)
		variable lp: line;
		variable pv: Std_Logic;
	begin
		if (reset = '1') then
		elsif rising_edge(clk) then
			if (data_out_en_s) = '1' then
				write(lp, integer'image(to_integer(signed(data_out_i_s))));
				write(lp, string'(" "));
				write(lp, integer'image(to_integer(signed(data_out_q_s))));
				writeline(final_result_file, lp);
			end if;
		end if;
	end process; 

	-- read data from a file and store this into a ram
	-- TBD : must be read I and Q 
	read_data : entity work.readFromFile
	generic map(
		DATA_SIZE => DATA_SIZE,
		ADDR_SIZE => ADDR_SIZE,
		filename =>
		"./data2q.dat"
	)
	port map (
		reset => reset,
		clk => clk,
		sl_clk_i => '1', --sl_clk_s,
		--fichier => datas,
		start_read_i => start_read_s,
		data_o => read_data_val_s,
		addr_o => read_data_addr_s,
		data_en_o => read_data_en_s,
		end_of_read_o => end_read2_s
	);
	
	ram_i : entity work.ram_storage16
	generic map(
		DATA => 16,
		ADDR => ADDR_SIZE
	)
	port map (
		clk_a => clk,
		clk_b => clk,
		reset => reset,
		-- input datas
		we_a => read_data_en_s,
		din_a => read_data_val_s,
		addr_a => read_data_addr_s,
		dout_a => open,
		-- output
		we_b => '0',
		addr_b => prop_data_addr_s,
		din_b => (15 downto 0 => '0'),
		dout_b => data_s
	);
	
	-- generate data flow
	prop_data_addr_s <= std_logic_vector(to_unsigned(prop_data_addr_nat_s, ADDR_SIZE));
	data_propagation : process(clk, reset)
	begin
		if (reset = '1') then
			prop_data_addr_nat_s <= 0;
			data_en_s <= '0';
		elsif rising_edge(clk) then
			data_en_s <= '0';
			prop_data_addr_nat_s <= prop_data_addr_nat_s;
			if tick_s = '1' then
					if prop_data_addr_nat_s = (2**ADDR_SIZE) -1 then
						prop_data_addr_nat_s <= 0;
						prop_data_addr_nat_s <= prop_data_addr_nat_s;
					else
						prop_data_addr_nat_s <= prop_data_addr_nat_s + 1;
					end if;
					data_en_s <= '1';
			end if;
		end if;
	end process; 

	end_simu_s <= '1' when res_cpt_s = MAX_RES_CPT-1 else '0';
	process(clk) begin
		if rising_edge(clk) then
			if reset = '1' then
				res_cpt_s <= 0;
			elsif data_out_en_s = '1' then
				if end_simu_s = '1' then
					res_cpt_s <= 0;
				else
					res_cpt_s <= res_cpt_s + 1;
				end if;
			else
				res_cpt_s <= res_cpt_s;
			end if;
		end if;
	end process;

    stimulis : process
    begin
	start_prod_s <= '0';
	start_read_s <= '0';
	start_read_coeff <= '0';
	reset <= '0';
	wait until rising_edge(clk);
	reset <= '1';
	wait until rising_edge(clk);
	wait until rising_edge(clk);
	wait until rising_edge(clk);
	reset <= '0';
    wait for 10 ns;
	start_read_coeff <= '1';
	start_read_s <= '1';
	wait until end_read_coeff = '1';
	wait until end_read2_s = '1';
	start_read_coeff <= '0';
	start_read_coeff <= '0';
	wait until rising_edge(clk);
	start_prod_s <= '1';
	wait until rising_edge(clk);
	report "fin de la lecture de la LUT" severity note;
	report "fin de la lecture des data" severity note;
	wait until rising_edge(end_simu_s);
	start_prod_s <= '0';
    wait for 10 us;
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
