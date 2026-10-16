library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_access is
    generic (
        DATA_WIDTH : positive := 16;
        N_WEIGHTS  : positive := 6;
        N_BIASES   : positive := 3
    );
    port (
        clk : in STD_LOGIC;

        write_enable : in STD_LOGIC;
        write_address : in integer range 0 to N_WEIGHTS + N_BIASES - 1;
        write_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        read_address : in integer range 0 to N_WEIGHTS + N_BIASES - 1;
        read_data : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end parameter_access;

architecture Behavioral of parameter_access is

    signal weight_write_enable : STD_LOGIC;
    signal bias_write_enable : STD_LOGIC;

    signal weight_write_addr : integer range 0 to N_WEIGHTS - 1;
    signal bias_write_addr : integer range 0 to N_BIASES - 1;

    signal weight_read_addr : integer range 0 to N_WEIGHTS - 1;
    signal bias_read_addr : integer range 0 to N_BIASES - 1;

    signal weight_read_data : SIGNED(DATA_WIDTH - 1 downto 0);
    signal bias_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    weight_write_enable <= '1'
        when write_enable = '1' and write_address < N_WEIGHTS
        else '0';

    bias_write_enable <= '1'
        when write_enable = '1' and write_address >= N_WEIGHTS
        else '0';

    weight_write_addr <= write_address
        when write_address < N_WEIGHTS else 0;

    bias_write_addr <= write_address - N_WEIGHTS
        when write_address >= N_WEIGHTS else 0;

    weight_read_addr <= read_address
        when read_address < N_WEIGHTS else 0;

    bias_read_addr <= read_address - N_WEIGHTS
        when read_address >= N_WEIGHTS else 0;

    read_data <= weight_read_data
        when read_address < N_WEIGHTS
        else bias_read_data;

    MEMORY : entity work.parameter_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk => clk,

            weight_write_enable => weight_write_enable,
            weight_write_addr => weight_write_addr,
            weight_write_data => write_data,

            weight_read_addr => weight_read_addr,
            weight_read_data => weight_read_data,

            -- Unused second weight read port
            weight_read_addr_b => 0,
            weight_read_data_b => open,

            bias_write_enable => bias_write_enable,
            bias_write_addr => bias_write_addr,
            bias_write_data => write_data,
            bias_read_addr => bias_read_addr,
            bias_read_data => bias_read_data
        );

end Behavioral;