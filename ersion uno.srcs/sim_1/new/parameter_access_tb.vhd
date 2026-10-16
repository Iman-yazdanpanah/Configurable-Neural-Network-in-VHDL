
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_access_tb is
end parameter_access_tb;

architecture Behavioral of parameter_access_tb is

    constant DATA_WIDTH : positive := 16;
    constant N_WEIGHTS : positive := 3;
    constant N_BIASES  : positive := 2;

    signal clk : STD_LOGIC := '0';

    signal write_enable : STD_LOGIC := '0';
    signal write_address : integer range 0 to 4 := 0;
    signal write_data : SIGNED(15 downto 0) := (others => '0');

    signal read_address : integer range 0 to 4 := 0;
    signal read_data : SIGNED(15 downto 0);

begin

    clk <= not clk after 5 ns;

    DUT : entity work.parameter_access
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk           => clk,
            write_enable  => write_enable,
            write_address => write_address,
            write_data    => write_data,
            read_address  => read_address,
            read_data     => read_data
        );

    stimulus : process
    begin

        -- Write weight 0 = 1.0 (512)
        write_enable <= '1';
        write_address <= 0;
        write_data <= to_signed(512, DATA_WIDTH);
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Write weight 2 = -0.5 (-256)
        write_address <= 2;
        write_data <= to_signed(-256, DATA_WIDTH);
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Write bias 0 = 2.0 (1024), unified address 3
        write_address <= 3;
        write_data <= to_signed(1024, DATA_WIDTH);
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Write bias 1 = -1.0 (-512), unified address 4
        write_address <= 4;
        write_data <= to_signed(-512, DATA_WIDTH);
        wait until rising_edge(clk);
        wait for 1 ns;

        write_enable <= '0';
        wait for 1 ns;

        -- TEST 1: Read weight 0
        read_address <= 0;
        wait for 1 ns;

        assert read_data = to_signed(512, DATA_WIDTH)
            report "TEST 1 FAILED: weight 0"
            severity error;

        report "TEST 1 PASSED: weight 0" severity note;

        -- TEST 2: Read weight 2
        read_address <= 2;
        wait for 1 ns;

        assert read_data = to_signed(-256, DATA_WIDTH)
            report "TEST 2 FAILED: weight 2"
            severity error;

        report "TEST 2 PASSED: negative weight" severity note;

        -- TEST 3: Read bias 0
        read_address <= 3;
        wait for 1 ns;

        assert read_data = to_signed(1024, DATA_WIDTH)
            report "TEST 3 FAILED: bias 0"
            severity error;

        report "TEST 3 PASSED: bias 0" severity note;

        -- TEST 4: Read bias 1
        read_address <= 4;
        wait for 1 ns;

        assert read_data = to_signed(-512, DATA_WIDTH)
            report "TEST 4 FAILED: bias 1"
            severity error;

        report "TEST 4 PASSED: negative bias" severity note;

        -- TEST 5: Confirm weight 0 was not overwritten
        read_address <= 0;
        wait for 1 ns;

        assert read_data = to_signed(512, DATA_WIDTH)
            report "TEST 5 FAILED: memory independence"
            severity error;

        report "TEST 5 PASSED: memory independence"
            severity note;

        report "ALL PARAMETER ACCESS TESTS PASSED"
            severity note;

        wait;
    end process;

end Behavioral;
