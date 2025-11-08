library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
generic (
    WORD : integer := 8;
    ADDRESSING : integer := 16
  );

    port(
        i_clk       : in std_logic;
        i_rst       : in std_logic;
        i_start     : in std_logic;
        i_add       : in std_logic_vector(ADDRESSING-1 downto 0);
        i_k         : in std_logic_vector(9 downto 0);
        i_mem_data  : in std_logic_vector(WORD-1 downto 0);
        
        o_mem_data  : out std_logic_vector(WORD-1 downto 0);
        o_done      : out std_logic;
        o_mem_en    : out std_logic;
        o_mem_we    : out std_logic;
        o_mem_addr  : out std_logic_vector( ADDRESSING-1 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    type state_t is (IDLE, MEM_READ, MEM_WRITE, DONE, SYNC_1, SYNC_2, SET_UP, SET_UP1);
    signal state : state_t := IDLE;

    signal add_reg      : std_logic_vector(ADDRESSING-1 downto 0);
    signal k_reg        : std_logic_vector(10 downto 0);
    signal counter      : std_logic_vector(10 downto 0) := b"00000000000";
    signal o_mem_addr_reg : std_logic_vector(ADDRESSING-1 downto 0) := x"0000";

    type state_e is (IDLE1, SYNC_FIRST, ELAB_FIRST_DATA, SYNC_2, OUT_C, WAIT_WRITE_C, SYNC_3, ELAB_DATA, WAIT_WRITE_D);
    signal state_elab : state_e := IDLE1;

    signal C    : std_logic_vector(WORD-1 downto 0);
    signal reg  : std_logic_vector(WORD-1 downto 0);

begin
    o_mem_addr <= o_mem_addr_reg;

    FSM_controller : process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_done          <= '0';
            o_mem_en        <= '0';
            o_mem_we        <= '0';
            o_mem_addr_reg  <= x"0000";
            counter         <= b"00000000000";
            state           <= SET_UP;
        
        elsif rising_edge(i_clk) then
            case (state) is
                when SET_UP =>
                    state <= IDLE;
                
                when IDLE =>
                    k_reg <= i_k & '0';
                    if i_start = '1' then 
                        o_mem_en       <= '1';
                        o_mem_we       <= '0';
                        o_mem_addr_reg <= i_add;    
                        state          <= SYNC_1;      
                    end if;

                when SYNC_1 =>
                    state <= MEM_READ;
                
                when MEM_READ =>
                    o_mem_we <= '1';
                    state    <= MEM_WRITE;

                when MEM_WRITE =>
                    if k_reg - 1 = counter then
                        counter         <= b"00000000000";
                        o_mem_en        <= '0';
                        state           <= DONE;
                    else
                        counter         <= counter + 1;
                        o_mem_we        <= '0';
                        o_mem_addr_reg  <= o_mem_addr_reg + 1;
                        state           <= SYNC_1;
                    end if;

                when DONE =>
                    if i_start = '0' then
                        o_done <= '0';
                        state  <= SET_UP;
                    else  
                        o_done <= '1'; 
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    FSM_elaboration : process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_mem_data <= b"00000000";
            state_elab <= IDLE1;
            reg        <= b"00000000";
        
        elsif rising_edge(i_clk) then
            if i_start = '1' then
                case (state_elab) is
                    when IDLE1 =>
                        state_elab <= SYNC_FIRST;
                    
                    when SYNC_FIRST =>
                        state_elab <= ELAB_FIRST_DATA;

                    when ELAB_FIRST_DATA =>
                        o_mem_data <= i_mem_data;
                        if i_mem_data /= b"00000000" then
                            C    <= "00011111";
                            reg  <= i_mem_data;
                            state_elab <= SYNC_2;
                        end if;    
                    
                    when SYNC_2 =>
                        state_elab <= OUT_C;

                    when OUT_C =>
                        if i_mem_data = "00000000" then
                            o_mem_data <= C;
                            state_elab <= WAIT_WRITE_C;
                        end if;

                    when WAIT_WRITE_C =>
                        state_elab <= SYNC_3;

                    when SYNC_3 =>
                        state_elab <= ELAB_DATA;

                    when ELAB_DATA =>
                        if i_mem_data /= "00000000" then
                            o_mem_data <= i_mem_data;
                            reg        <= i_mem_data;
                            C          <= "00011111";
                            state_elab <= WAIT_WRITE_D;
                        else
                            if C = 0 then
                                o_mem_data <= reg;
                                state_elab <= WAIT_WRITE_D;
                            else
                                C          <= C - 1;
                                o_mem_data <= reg;
                                state_elab <= WAIT_WRITE_D;
                            end if;
                        end if;

                    when WAIT_WRITE_D =>
                        state_elab <= SYNC_2;

                end case;
            else
                o_mem_data <= b"00000000";
                state_elab <= IDLE1;
                reg        <= b"00000000";
            end if;
        end if;
    end process;

end Behavioral;
