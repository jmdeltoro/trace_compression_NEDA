----------------------------------------------------------------------------------
-- Code developed by Jose Manuel Deltoro Berrio
-- University of Valencia - Escuela Técnica Superior d'Enginyeria (ETSE)
---------------------------------
-- Create Date:    16:14:19 10/02/2018 
-- Module Name:    compression_trace - Behavioral 
-- Project Name:  NUMEXO2 firmware NEDA
-- Target Devices: FPGA - Virtex-6

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_SIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.types_dcfd.all;

entity compression_trace is

Port (
	clk 					: in std_logic;
	rst 					: in std_logic;
	write_in				: in std_logic;
	SAMPLE0_in			: in std_logic_vector (14 downto 0);
	SAMPLE1_in 			: in std_logic_vector (14 downto 0);
	enable_comp 		: in std_logic;
	comp_pre_peak 		: in std_logic_vector (7 downto 0);
	comp_peak			: in std_logic_vector (7 downto 0);
	zco_postion			: in std_logic_vector (7 downto 0);
	process_compression: out std_logic;
	read_OUT_sig 		: out std_logic;
	sample_diff0_debug: out std_logic_vector (14 downto 0);
	sample_diff1_debug: out std_logic_vector (14 downto 0);
	reading_comp_out	: out	std_logic;
	SAMPLE1_joined		: out std_logic_vector (15 downto 0);
	SAMPLE0_joined		: out std_logic_vector (15 downto 0);
	size_trace_out 	: out std_logic_vector (15 downto 0);
	size_pre_peak		: out std_logic_vector (7 downto 0);
	size_peak			: out std_logic_vector (7 downto 0);

	SAMPLE0diff_out	: out std_logic_vector (15 downto 0);
	SAMPLE1diff_out 	: out std_logic_vector (15 downto 0)
);
end compression_trace;

architecture Behavioral of compression_trace is

signal SAMPLE0_in_sig  : std_logic_vector (14 downto 0):= (others => '0');
signal SAMPLE1_in_sig  : std_logic_vector (14 downto 0):= (others => '0');
signal SAMPLE1_in_sig_dly	  : std_logic_vector (14 downto 0):= (others => '0');
signal read_en  : std_logic:='0';
signal write_fifo_256 : std_logic:='0';
signal first: std_logic:='1';
signal first_samp: std_logic:='1';
signal second_samp: std_logic:='1';
signal second: std_logic:='1';
signal wait_samp: std_logic:='1';
signal firstsamples: std_logic_vector (1 downto 0):= (others => '0');
signal wr0_en_out : std_logic:='0';
signal rd0_en_out : std_logic:='0';
signal empty0_out : std_logic:='0';
signal full0_out : std_logic:='0';

signal wr1_en_out : std_logic:='0';
signal rd1_en_out : std_logic:='0';
signal empty1_out : std_logic:='0';
signal full1_out : std_logic:='0';
signal reading_OUT_sig: std_logic:='0';

signal counter	: std_logic_vector (2 downto 0):= (others => '0');
signal count_header : std_logic_vector (5 downto 0):= (others => '0'); 

signal count_wait	: std_logic_vector (1 downto 0):= (others => '0');

signal cnt_compress		: std_logic_vector (7 downto 0):= (others => '0'); -- counter for compression
signal cnt_diff		: std_logic_vector (7 downto 0):= (others => '0'); -- counter for differences
signal cnt_nocomp		: std_logic_vector (7 downto 0):= (others => '0'); -- counter for no comprees samples
signal cnt_nocompress		: std_logic_vector (8 downto 0):= (others => '0'); -- counter for no comprees samples



signal count_samples_peak_comp	: std_logic_vector (8 downto 0):= (others => '0');
signal count_samples_pre_comp	: std_logic_vector (8 downto 0):= (others => '0');
signal count: std_logic_vector (3 downto 0):= (others => '0');
signal count_aux: std_logic_vector (3 downto 0):= (others => '0');

signal sample_diff0_out_fifo  : std_logic_vector (14 downto 0):= (others => '0');
signal sample_diff1_out_fifo  : std_logic_vector (14 downto 0):= (others => '0');


signal sample_diff0_in_sig  : std_logic_vector (14 downto 0):= (others => '0');
signal sample_diff1_in_sig  : std_logic_vector (14 downto 0):= (others => '0');
signal SAMPLE0_out_sig  : std_logic_vector (15 downto 0):= (others => '0');
signal SAMPLE1_out_sig  : std_logic_vector (15 downto 0):= (others => '0');
signal comp_pre_peak_sig : std_logic_vector (7 downto 0):= (others => '0');

signal compress_SAMPLE0_out  : std_logic_vector (15 downto 0):= (others => '0');
signal compress_SAMPLE1_out  : std_logic_vector (15 downto 0):= (others => '0');
signal size_trace : std_logic_vector (15 downto 0):= (others => '0');
signal trace_size	: std_logic_vector (15 downto 0):= (others => '0');

type state_comp is (INIT, WAITING, DIFF_SAMPLES);
signal current_state : state_comp;

type state_mov is (INIT, TAKE_even, TAKE_odd);
signal mov_state : state_mov;

type pack is (INITIAL, samples_pre, samples_peak, samples_post,FIRST_SAMPLES);
signal pack_state : pack;

type joining is (START, READING_B, READING_A, JOIN_B, JOIN_A, READING_OUT, WAITING);
signal join_state : joining;

function mask_ones (sample_in: std_logic_vector(14 downto 0); n : integer; pos : integer) return std_logic_vector is
	variable v : std_logic_vector (15 downto 0) := (others => '0');
	variable sample_in15 : std_logic_vector (15 downto 0) := (others => '0');
	--variable position : integer;
begin
	sample_in15 := '0' & sample_in;
	for i in 0 to 15 loop
		if (i < n) then
			v(i) := '1';
		else
			v(i) := '0';
		end if;
	end loop;
	v := sample_in15 and v;
	v := shift_left(v,pos);
	return std_logic_vector(v);
end function;


function refresh_position (n : integer; pos : integer) return integer is
	variable position : integer;
begin
	position := pos - n;
		return integer(position);
end function;


begin
SAMPLE0_in_sig <= SAMPLE0_in;
SAMPLE1_in_sig <= SAMPLE1_in;

--comp_pre_peak_sig <= zco_postion - comp_pre_peak;


calc_differences : process (clk,rst,write_in,enable_comp) -- Calculation of differences in the input samples
begin

	if (rst = '1') then 

	SAMPLE1_in_sig_dly <= (others => '0');
	elsif (rising_edge(clk)) then
		case current_state is
			when INIT =>
				sample_diff0_in_sig	<= (others => '0');
				sample_diff1_in_sig	<= (others => '0');
				--count_waiting<= (others => '0');
				--write_fifos  <= '0';	
				firstsamples <= (others => '0');
				cnt_nocomp  <= (others => '0');	
		--		compression_start <= '0';
				SAMPLE1_in_sig_dly <= (others => '0');
				if write_in = '1' and enable_comp  = '1' then   ---for the future add condition pile-up
					current_state <= WAITING;
					
		--			compression_start <= '1';
				end if;
				
			when WAITING =>
					--firstsamples <= firstsamples + 1;
					--if firstsamples = "01" then
						--write_fifos  <= '1';
						sample_diff0_in_sig <= std_logic_vector(signed(SAMPLE0_in_sig));
						sample_diff1_in_sig <= std_logic_vector(signed(SAMPLE1_in_sig));
						SAMPLE1_in_sig_dly <= SAMPLE1_in_sig;
						current_state <= DIFF_SAMPLES;
					--end if;
	
			when DIFF_SAMPLES =>
					--write_fifos  <= '1';
					if pack_state = SAMPLES_peak then--or pack_state = FIRST_SAMPLES
						
					--if (cnt_diff >= comp_pre_peak ) and  (cnt_nocomp < comp_peak) then --cambio para no diferencia
						sample_diff0_in_sig <= std_logic_vector(signed(SAMPLE0_in_sig)); --cambio para no diferencia
						sample_diff1_in_sig <= std_logic_vector(signed(SAMPLE1_in_sig)); --cambio para no diferencia
						cnt_nocomp <= cnt_nocomp + 1; --cambio para no diferencia
				  -- SAMPLE1_in_sig_dly <= SAMPLE1_in_sig;
					else--cambio para no diferencia
						sample_diff0_in_sig <= std_logic_vector(signed(SAMPLE0_in_sig) - signed(SAMPLE1_in_sig_dly));
						sample_diff1_in_sig <= std_logic_vector(signed(SAMPLE1_in_sig) - signed(SAMPLE1_in_sig_dly));--signed(SAMPLE1_in_sig_dly)); --(1_dly para diferencia con la primera muestra, 0 con la anterior)  -- signed(SAMPLE0_in_sig));
						--SAMPLE1_in_sig_dly <= SAMPLE1_in_sig;--descomentar para  diferencia entre muestras sucesivas (comentar para diferencia con primeras muestras)
					end if;--cambio para no diferencia
					
				if write_in = '0' then
					--write_fifos  <= '0';	
					current_state <= INIT;
				end if;
			end case;
	end if;		
end process;


counter_differences : process (clk,rst,current_state,cnt_diff)
begin
	if (rst = '1') then
      cnt_diff <= (others => '0');
   elsif (rising_edge(clk)) then
         if (current_state = DIFF_SAMPLES) then
			 cnt_diff <= cnt_diff + 1;
         else
           cnt_diff <= (others => '0');
         end if;
   end if;
end process;





 sample_diff0_debug <=  sample_diff0_in_sig;
 sample_diff1_debug <=  sample_diff1_in_sig;


packaging : process (clk,rst) 
begin

if (rst = '1') then
		
	elsif (rising_edge(clk)) then
		case pack_state is
			when INITIAL =>

				count_aux<= (others => '0');
				count <= (others => '0');

				if current_state = DIFF_SAMPLES then
					count_samples_peak_comp <= (others => '0'); 
				   count_samples_pre_comp  <= (others => '0');

					pack_state <= FIRST_SAMPLES;

				end if;
				cnt_nocompress <= (others => '0');
			when FIRST_SAMPLES =>
				count_samples_pre_comp <= comp_pre_peak & '0' ;
				pack_state <= SAMPLES_pre;
	
					
			when SAMPLES_pre =>
				if comp_pre_peak <= cnt_compress then
					pack_state <= SAMPLES_peak;
				end if;
								
			when SAMPLES_peak =>
				if count_aux < 5 then
					count_aux <= count_aux + 1;
				end if;
	
			   cnt_nocompress <=  cnt_nocompress + 1;
				if (comp_peak <= cnt_nocompress) then
					pack_state <= SAMPLES_post;
				end if;
			
			when SAMPLES_post	=>
				
				if count < 7 then
				count <= count + 1;
				end if;
				
				if write_in = '0' then
					pack_state <= INITIAL;
				end if;
		
			end case;
	end if;		
end process;



size_pre_peak	<= count_samples_pre_comp(7 downto 0);
size_peak	<= count_samples_peak_comp(7 downto 0);




counter_compression : process (clk,rst,pack_state,cnt_compress)
begin
	if (rst = '1') then
      cnt_compress <= (others => '0');
   elsif (rising_edge(clk)) then
         if (pack_state = FIRST_SAMPLES  or pack_state = SAMPLES_pre or pack_state = SAMPLES_peak or pack_state = SAMPLES_post) then
			 cnt_compress <= cnt_compress + 1;
         else
           cnt_compress <= (others => '0');
         end if;
   end if;
end process;






join_samples : process (clk,rst,empty1_out,empty0_out,pack_state,write_fifo_256) 
begin

if (rst = '1') then
		SAMPLE0_out_sig <= (others => '0');
		SAMPLE1_out_sig <= (others => '0');
	   --fifo_out_256_pre <= (others => '0');
	elsif (rising_edge(clk)) then
		case join_state is	
		
			when START =>
					SAMPLE0_out_sig <= (others => '0');
					SAMPLE1_out_sig <= (others => '0');
					reading_OUT_sig <= '0';
					reading_comp_out<= '0';
					second_samp <= '1';
					size_trace <= x"0000";
					count_header <= (others => '0');
					--count_wait <= (others => '0');
					wr0_en_out <= '0';
					wr1_en_out <= '0';
					--first_samp  <= '1';
					rd0_en_out <= '0';
					rd1_en_out <= '0';
					trace_size <= x"0000";
				if current_state = WAITING then
				--if empty_fifo_even = '0' then
			--		read_fifo_256 <= '1';
					size_trace <= x"0000";
					trace_size <= x"0000";
					
				--	compression_start <= '0';
				--	count_wait <= count_wait + 1;
				--	if count_wait = 1 then
					join_state <= READING_A;
					--read_en_even <= '1';
					--read_en_odd <= '1';	
					--wr0_en_out <= '1';
					--wr1_en_out <= '1';
					SAMPLE0_out_sig <= '0' & sample_diff0_in_sig;
					SAMPLE1_out_sig <= '0' & sample_diff1_in_sig;
					--SAMPLE0_out_sig <= sample_diff0_out_fifo;
					--SAMPLE1_out_sig <= sample_diff1_out_fifo;


					
					--count_wait <= (others => '0');
					size_trace <= size_trace + 1;
						--compression_start <= '1';
				--	end if;
				end if;	
	
				
			when JOIN_B =>
					
					if size_trace > trace_size and trace_size /= X"0000" then
						SAMPLE1_out_sig <= X"F0F0";
					else 
						SAMPLE1_out_sig <= sample_diff0_in_sig(7 downto 0) & sample_diff1_in_sig(7 downto 0);
						--SAMPLE1_out_sig <= fifo_out_256_pre or fifo_out_256;
					end if;		

					
					join_state <= JOIN_A;
					wr0_en_out <= '1';
					wr1_en_out <= '1';
					size_trace <= size_trace + 1;	
					
					if pack_state = INITIAL then
						join_state <= READING_OUT;
						SAMPLE0_out_sig <= (others => '0');
						SAMPLE1_out_sig <= (others => '0');

						--read_en_even <= '0';
						--read_en_odd <= '0';
						--size_trace_out <= trace_size;
						wr0_en_out <= '0';						
						wr1_en_out <= '0';
					end if;	
												
			when READING_A =>
--					wr0_en_out <= '0';
--					
--				if (pack_state = SAMPLES_peak and count_aux > 2) or  (pack_state = SAMPLES_post and count < 1)  or first_samp = '1' then -- 
					SAMPLE0_out_sig <= '0' & sample_diff0_in_sig;
					SAMPLE1_out_sig <= '0' & sample_diff1_in_sig;
--					first_samp <= '0'; 
--					join_state <= READING_B;
--					wr0_en_out <= '0';
--					wr1_en_out <= '1';
--					size_trace <= size_trace + 1;	
--					--size_trace_out <= size_trace;
--				else
--					fifo_out_256_pre <= fifo_out_256;
					if pack_state = SAMPLES_peak then
						join_state <= READING_A;
						SAMPLE0_out_sig <= '0' & sample_diff0_in_sig;
						SAMPLE1_out_sig <= '0' & sample_diff1_in_sig;
					else
						join_state <= JOIN_A;
						wr0_en_out <= '1';
						wr1_en_out <= '1';
					
					
					end  if;	

				
			when JOIN_A =>
					if size_trace > trace_size and trace_size /= X"0000" then
						SAMPLE0_out_sig <= X"F0F0";
					else 
					
					SAMPLE0_out_sig <= sample_diff0_in_sig(7 downto 0) & sample_diff1_in_sig(7 downto 0);
					--SAMPLE0_out_sig <= fifo_out_256_pre or fifo_out_256;
					end if;
					
					join_state <= JOIN_B;
					wr0_en_out <= '0';
					wr1_en_out <= '0';
					size_trace <= size_trace + 1;	
					--size_trace_out <= size_trace;
					
					if pack_state = SAMPLES_peak then
						wr0_en_out <= '1';
						wr1_en_out <= '1';
						join_state <= READING_A;
						SAMPLE0_out_sig <= '0' & sample_diff0_in_sig;
						SAMPLE1_out_sig <= '0' & sample_diff1_in_sig;
					end if;
										
					--if empty_fifo_even = '1' and size_trace = X"0100" then
					if pack_state = INITIAL then
						join_state <= READING_OUT;
						SAMPLE0_out_sig <= (others => '0');
						SAMPLE1_out_sig <= (others => '0');
						--size_trace_out <= trace_size;
						wr0_en_out <= '0';
						wr1_en_out <= '0';
						--read_en_even <= '0';
						--read_en_odd <= '0';
					end if;	
					
			when READING_OUT =>
					reading_OUT_sig <= '1';
					reading_comp_out <= '1';
					count_header <= count_header + 1;
					wr0_en_out <= '0';
					wr1_en_out <= '0';

					if count_header > 10 then
						rd0_en_out <= '1';
						rd1_en_out <= '1';
					end if;
					--read_fifo_256 <= '0';
					
				if empty0_out = '1' and empty1_out = '1' then
					join_state <= WAITING;
					reading_OUT_sig <= '0';
					--reading_comp_out<= '0';
				--	process_compression <= '0';
				end if;
			
			when WAITING =>
				join_state <= START;
			
			
			when others =>
				join_state <= START;

			
			end case;
	end if;		
end process;

monitoring : process (clk,rst,empty1_out,empty0_out,current_state) 
begin

	if (rst = '1') then
		process_compression <= '0';
	elsif (rising_edge(clk)) then
		if current_state = DIFF_SAMPLES then
			process_compression <= '1';
		end if;
		
		if join_state =  WAITING then
			process_compression <= '0';
		end if;
	end if;
end process;

------DEBUG ----- 

--
--
--debug_mov_compression : process(mov_state)
--begin
--	case mov_state is
--		when INIT			=> 	debug_mov_comp <= "00";
--		when TAKE_odd 		=> 	debug_mov_comp <= "01";
--		when TAKE_even 	=> 	debug_mov_comp <= "10";
--		when others 	=>		debug_mov_comp <= "11";
--	end case;
--end process;
--
--
--debug_pack_compression : process(pack_state)
--begin
--	case pack_state is
--		when INITIAL		=> 	debug_pack_comp <= "000";
--		when samples_pre => 	debug_pack_comp <= "001";
--		when samples_peak 	=> 	debug_pack_comp <= "010";
--		when samples_post => 	debug_pack_comp <= "011";
--		when FIRST_SAMPLES 	=> 	debug_pack_comp <= "100";
--		when others 	=>		debug_pack_comp <= "111";
--	end case;
--end process;
--
--
--debug_state_compression : process(join_state)
--begin
--	case join_state is
--		when START		=> 	debug_state_comp <= "000";
--		when READING_A => 	debug_state_comp <= "001";
--		when JOIN_A 	=> 	debug_state_comp <= "010";
--		when READING_B => 	debug_state_comp <= "011";
--		when JOIN_B 	=> 	debug_state_comp <= "100";
--		when WAITING  	=>		debug_state_comp <= "101";
--		when READING_OUT 	=>		debug_state_comp <= "110";
--		when others 	=>		debug_state_comp <= "111";
--	end case;
--end process;
--
--
--
--
--
--debug_state_comp_diff : process(current_state)
--begin
--	case current_state is
--		when INIT		=> 	debug_diff_comp <= "00";
--		when WAITING 	=> 	debug_diff_comp <= "01";
--		when DIFF_SAMPLES => 	debug_diff_comp <= "10";
--	end case;
--end process;
--



-------------- end debug ----

--storage_differences_even : entity work.FIFO_DIFF
--  PORT MAP (
--    clk => clk,
--    rst => rst,
--    din => sample_diff0_in_sig,
--    wr_en => write_fifos,
--    rd_en => read_en_even,
--    dout => sample_diff0_out_fifo,
--    full => full_fifo_even,
--    empty => empty_fifo_even
--  );
  

--storage_differences_odd : entity work.FIFO_DIFF
--  PORT MAP (
--    clk => clk,
--    rst => rst,
--    din => sample_diff1_in_sig,
--    wr_en => write_fifos,
--    rd_en => read_en_odd,
--    dout => sample_diff1_out_fifo,
--    full => full_fifo_odd,
--    empty => empty_fifo_odd
--  );
  
--differences256 : entity work.all_differences
--  PORT MAP (
--    clk => clk,
--    rst => rst,
--    din => fifo_in_256,
--    wr_en => write_fifo_256,
--    rd_en => read_fifo_256,
--    dout => fifo_out_256,
--    full => full_fifo_256,
--    empty => empty_fifo_256
--  );
--  
  sample_joined_0 : entity work.packed_samples
  PORT MAP (
    clk => clk,
    rst => rst,
    din => SAMPLE0_out_sig,
    wr_en => wr0_en_out,
    rd_en => rd0_en_out,
    dout => compress_SAMPLE0_out,
    full => full0_out,
    empty => empty0_out
  );
  
    sample_joined_1 : entity work.packed_samples
  PORT MAP (
    clk => clk,
    rst => rst,
    din => SAMPLE1_out_sig,
    wr_en => wr1_en_out,
    rd_en => rd1_en_out,
    dout => compress_SAMPLE1_out,
    full => full1_out,
    empty => empty1_out
  );
  
  
  
  
  
	SAMPLE1_joined	<= SAMPLE1_out_sig;
  	SAMPLE0_joined	<= SAMPLE0_out_sig;
	size_trace_out <= X"00E8";
 -- size_trace_out <= trace_size; --when the problem in the server was solved uncomment
 -- empty_fifos_comp <= empty1_out and empty0_out;
  read_OUT_sig  <= reading_OUT_sig;
  SAMPLE0diff_out  <= compress_SAMPLE0_out;
  SAMPLE1diff_out  <= compress_SAMPLE1_out ;

  
end Behavioral;



