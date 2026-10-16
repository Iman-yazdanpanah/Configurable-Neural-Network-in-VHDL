library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_memory is
    generic (
        DATA_WIDTH : positive := 16;
        N_WEIGHTS  : positive := 6;
        N_BIASES   : positive := 3
    );
    port (
        clk : in STD_LOGIC;

        -- Weight write interface
        weight_write_enable : in STD_LOGIC;
        weight_write_addr   : in integer range 0 to N_WEIGHTS - 1;
        weight_write_data   : in SIGNED(DATA_WIDTH - 1 downto 0);

        -- Original weight read port
        weight_read_addr    : in integer range 0 to N_WEIGHTS - 1;
        weight_read_data    : out SIGNED(DATA_WIDTH - 1 downto 0);

        -- Additional independent weight read port
        weight_read_addr_b  : in integer range 0 to N_WEIGHTS - 1;
        weight_read_data_b  : out SIGNED(DATA_WIDTH - 1 downto 0);

        -- Bias write interface
        bias_write_enable : in STD_LOGIC;
        bias_write_addr   : in integer range 0 to N_BIASES - 1;
        bias_write_data   : in SIGNED(DATA_WIDTH - 1 downto 0);

        -- Bias read interface
        bias_read_addr    : in integer range 0 to N_BIASES - 1;
        bias_read_data    : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end parameter_memory;

architecture Behavioral of parameter_memory is

    type weight_memory_t is array (0 to N_WEIGHTS - 1)
        of SIGNED(DATA_WIDTH - 1 downto 0);

    type bias_memory_t is array (0 to N_BIASES - 1)
        of SIGNED(DATA_WIDTH - 1 downto 0);

    signal weight_memory : weight_memory_t;
    signal bias_memory   : bias_memory_t;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if weight_write_enable = '1' then
                weight_memory(weight_write_addr) <= weight_write_data;
            end if;

            if bias_write_enable = '1' then
                bias_memory(bias_write_addr) <= bias_write_data;
            end if;
        end if;
    end process;

    -- Two independent asynchronous weight reads
    weight_read_data   <= weight_memory(weight_read_addr);
    weight_read_data_b <= weight_memory(weight_read_addr_b);

    -- Bias read
    bias_read_data <= bias_memory(bias_read_addr);

end Behavioral;