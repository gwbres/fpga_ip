library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

	Entity wb_dataReal_dma_direct is 
	generic (
		NB_INPUT  : natural := 1; -- number of 32bits to send
		NB_SAMPLE : natural := 10;
		wb_size   : natural := 16
	);
	port (
		-- CANDR
		reset         : in std_logic;
		clk	          : in std_logic;
		-- Wishbone signals
		wbs_add	      : in std_logic_vector(1 downto 0);
		wbs_writedata : in std_logic_vector(wb_size-1 downto 0);
		wbs_readdata  : out std_logic_vector(wb_size-1 downto 0);
		wbs_read      : in std_logic;
		wbs_read_ack  : out std_logic;
		wbs_write     : in std_logic;
		busy_i        : in std_logic;
		start_o       : out std_logic
	);
end entity wb_dataReal_dma_direct;

-----------------------------------------------------------------------
Architecture wb_dataReal_dma_direct_1 of wb_dataReal_dma_direct is
-----------------------------------------------------------------------
	constant REG_START  : std_logic_vector(1 downto 0) := "01";
	constant REG_SIZE   : std_logic_vector(1 downto 0) := "10";
	signal readdata_s : std_logic_vector(wb_size-1 downto 0);
	-- byte size
	constant NB_BYTE : natural := NB_SAMPLE * 4;
	constant CPT_SIZE : natural := natural(ceil(log2(real(NB_BYTE))));
	constant SIZE_N : natural := CPT_SIZE;
	constant buff_size_s : unsigned(CPT_SIZE-1 downto 0) := to_unsigned(NB_BYTE, CPT_SIZE);
	constant plop2: unsigned(SIZE_N-1 downto 0) := buff_size_s;
	signal plop : std_logic_vector(wb_size-1 downto 0);
begin
	wbs_readdata <= readdata_s;

	same_sz : if wb_size = SIZE_N generate
		plop <= std_logic_vector(plop2);
	end generate same_sz;
	gt_sz : if wb_size > SIZE_N generate
		plop <= (wb_size-1 downto SIZE_N => '0') &
			std_logic_vector(plop2);
	end generate gt_sz;
	lt_sz : if wb_size < SIZE_N generate
		plop <= std_logic_vector(plop2);
	end generate lt_sz;


	-- manage register
	write_bloc : process(clk) begin
		 if rising_edge(clk) then
		 	if reset = '1' then 
				start_o <= '0';
			 else
				start_o <= '0';
				if (wbs_write = '1' and wbs_add = REG_START) then
					start_o <= wbs_writedata(0);
				end if;
			end if;
		 end if;
	end process write_bloc;

	read_bloc : process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				readdata_s <= (others => '0');
				wbs_read_ack <= '0';
			else
				wbs_read_ack <= '0';
		 		readdata_s <= readdata_s;
				if (wbs_read = '1') then
					wbs_read_ack <= '1';
					case wbs_add is
					when REG_START		=>			
						readdata_s <= (wb_size-1 downto 1 => '0')&busy_i;
					when REG_SIZE		=>			
						readdata_s <= plop;
					when others =>
						readdata_s <= x"AA55AA55";  -- lecture dans reg inconnu
					end case;
				end if;
			end if;
		end if;
	end process read_bloc;
end architecture wb_dataReal_dma_direct_1;

