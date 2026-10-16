
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_memory_tb is
end parameter_memory_tb;

architecture Behavioral of parameter_memory_tb is

    constant DATA_WIDTH : positive := 16;
    constant N_WEIGHTS  : positive := 6;
    constant N_BIASES   : positive := 3;

    signal clk : STD_LOGIC := '0';

    signal weight_write_enable : STD_LOGIC := '0';
    signal weight_write_addr : integer range 0 to N_WEIGHTS - 1 := 0;
    signal weight_write_data : SIGNED(DATA_WIDTH - 1 downto 0)
        := (others => '0');
    signal weight_read_addr : integer range 0 to N_WEIGHTS - 1 := 0;
    signal weight_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

    signal bias_write_enable : STD_LOGIC := '0';
    signal bias_write_addr : integer range 0 to N_BIASES - 1 := 0;
    signal bias_write_data : SIGNED(DATA_WIDTH - 1 downto 0)
        := (others => '0');
    signal bias_read_addr : integer range 0 to N_BIASES - 1 := 0;
    signal bias_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    -- 10 ns clock period
    clk <= not clk after 5 ns;

    uut : entity work.parameter_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk => clk,

            weight_write_enable => weight_write_enable,
            weight_write_addr   => weight_write_addr,
            weight_write_data   => weight_write_data,
            weight_read_addr    => weight_read_addr,
            weight_read_data    => weight_read_data,

            bias_write_enable => bias_write_enable,
            bias_write_addr   => bias_write_addr,
            bias_write_data   => bias_write_data,
            bias_read_addr    => bias_read_addr,
            bias_read_data    => bias_read_data
        );

    stimulus : process
    begin

        ------------------------------------------------
        -- TEST 1: Write and read a weight
        ------------------------------------------------
        weight_write_addr <= 0;
        weight_write_data <= to_signed(512, DATA_WIDTH); -- 1.0 in Q9
        weight_write_enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        weight_write_enable <= '0';
        weight_read_addr <= 0;

        wait for 1 ns;

        assert weight_read_data = to_signed(512, DATA_WIDTH)
            report "ERROR: Weight 0 readback failed"
            severity failure;

        report "TEST 1 PASSED: Weight write/read."
            severity note;


        ------------------------------------------------
        -- TEST 2: Write and read another weight
        ------------------------------------------------
        wait until falling_edge(clk);

        weight_write_addr <= 4;
        weight_write_data <= to_signed(-256, DATA_WIDTH); -- -0.5
        weight_write_enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        weight_write_enable <= '0';
        weight_read_addr <= 4;

        wait for 1 ns;

        assert weight_read_data = to_signed(-256, DATA_WIDTH)
            report "ERROR: Weight 4 readback failed"
            severity failure;

        report "TEST 2 PASSED: Negative weight storage."
            severity note;


        ------------------------------------------------
        -- TEST 3: Write and read a bias
        ------------------------------------------------
        wait until falling_edge(clk);

        bias_write_addr <= 1;
        bias_write_data <= to_signed(2048, DATA_WIDTH); -- 4.0
        bias_write_enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        bias_write_enable <= '0';
        bias_read_addr <= 1;

        wait for 1 ns;

        assert bias_read_data = to_signed(2048, DATA_WIDTH)
            report "ERROR: Bias 1 readback failed"
            severity failure;

        report "TEST 3 PASSED: Bias write/read."
            severity note;


        ------------------------------------------------
        -- TEST 4: Confirm previously stored data remains
        ------------------------------------------------
        weight_read_addr <= 0;
        bias_read_addr <= 1;

        wait for 1 ns;

        assert weight_read_data = to_signed(512, DATA_WIDTH)
            report "ERROR: Previously stored weight changed"
            severity failure;

        assert bias_read_data = to_signed(2048, DATA_WIDTH)
            report "ERROR: Previously stored bias changed"
            severity failure;

        report "TEST 4 PASSED: Independent storage."
            severity note;

        report "ALL PARAMETER MEMORY TESTS PASSED."
            severity note;

        wait;
    end process;

end Behavioral;
