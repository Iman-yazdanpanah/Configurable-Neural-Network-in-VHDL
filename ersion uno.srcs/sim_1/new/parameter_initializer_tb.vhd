
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_initializer_tb is
end parameter_initializer_tb;

architecture Simulation of parameter_initializer_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_WEIGHTS  : positive := 6;
    constant N_BIASES   : positive := 3;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal start : STD_LOGIC := '0';
    signal seed  : STD_LOGIC_VECTOR(15 downto 0) := x"ACE1";

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

    signal weight_write_enable : STD_LOGIC;
    signal weight_write_addr   : integer range 0 to N_WEIGHTS - 1;
    signal weight_write_data   : SIGNED(DATA_WIDTH - 1 downto 0);

    signal bias_write_enable : STD_LOGIC;
    signal bias_write_addr   : integer range 0 to N_BIASES - 1;
    signal bias_write_data   : SIGNED(DATA_WIDTH - 1 downto 0);

    signal weight_read_addr : integer range 0 to N_WEIGHTS - 1 := 0;
    signal weight_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

    signal bias_read_addr : integer range 0 to N_BIASES - 1 := 0;
    signal bias_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

    -- Detect U, X, Z and other non-binary values.
    function has_unknown(v : STD_LOGIC_VECTOR) return BOOLEAN is
    begin
        for i in v'range loop
            if v(i) /= '0' and v(i) /= '1' then
                return true;
            end if;
        end loop;
        return false;
    end function;

begin

    ----------------------------------------------------------------
    -- Clock: 10 ns period
    ----------------------------------------------------------------
    clk <= not clk after 5 ns;

    ----------------------------------------------------------------
    -- Initializer under test
    ----------------------------------------------------------------
    DUT : entity work.parameter_initializer
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            seed  => seed,

            busy => busy,
            done => done,

            weight_write_enable => weight_write_enable,
            weight_write_addr   => weight_write_addr,
            weight_write_data   => weight_write_data,

            bias_write_enable => bias_write_enable,
            bias_write_addr   => bias_write_addr,
            bias_write_data   => bias_write_data
        );

    ----------------------------------------------------------------
    -- Existing parameter memory
    ----------------------------------------------------------------
    MEMORY : entity work.parameter_memory
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

    ----------------------------------------------------------------
    -- Test procedure
    ----------------------------------------------------------------
    stimulus : process
    begin

        -- TEST 1: Release reset
        reset <= '1';
        start <= '0';

        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '0' and done = '0'
            report "TEST 1 FAILED: Incorrect initial status"
            severity failure;

        report "TEST 1 PASSED: Initial state is correct"
            severity note;

        -- TEST 2: Start initialization
        wait until falling_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '1'
            report "TEST 2 FAILED: Busy was not asserted"
            severity failure;

        report "TEST 2 PASSED: Initialization started"
            severity note;

        -- Release start while initialization continues.
        wait until falling_edge(clk);
        start <= '0';

        -- Wait for completion, with a timeout.
        for i in 0 to 100 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            exit when done = '1';
        end loop;

        assert done = '1'
            report "TEST FAILED: Initialization timed out"
            severity failure;

        assert busy = '0'
            report "TEST FAILED: Busy still asserted after completion"
            severity failure;

        report "TEST 3 PASSED: Initialization completed"
            severity note;

        ----------------------------------------------------------------
        -- TEST 4: Verify every weight memory entry
        ----------------------------------------------------------------
        for i in 0 to N_WEIGHTS - 1 loop
            weight_read_addr <= i;
            wait for 1 ns;

            assert not has_unknown(
                STD_LOGIC_VECTOR(weight_read_data)
            )
                report "TEST FAILED: Weight memory contains unknown data"
                severity failure;

            report "Weight address " & integer'image(i) &
                   " = " & integer'image(to_integer(weight_read_data))
                severity note;
        end loop;

        report "TEST 4 PASSED: All weights were initialized"
            severity note;

        ----------------------------------------------------------------
        -- TEST 5: Verify every bias memory entry
        ----------------------------------------------------------------
        for i in 0 to N_BIASES - 1 loop
            bias_read_addr <= i;
            wait for 1 ns;

            assert not has_unknown(
                STD_LOGIC_VECTOR(bias_read_data)
            )
                report "TEST FAILED: Bias memory contains unknown data"
                severity failure;

            report "Bias address " & integer'image(i) &
                   " = " & integer'image(to_integer(bias_read_data))
                severity note;
        end loop;

        report "TEST 5 PASSED: All biases were initialized"
            severity note;

        ----------------------------------------------------------------
        -- TEST 6: Verify the first generated value
        ----------------------------------------------------------------
        -- Seed ACE1 has low byte E1, which is signed -31.
        weight_read_addr <= 0;
        wait for 1 ns;

        assert weight_read_data = to_signed(-31, DATA_WIDTH)
            report "TEST FAILED: First weight does not match the seed"
            severity failure;

        report "TEST 6 PASSED: Seeded random sequence is correct"
            severity note;

        report "ALL PARAMETER INITIALIZER TESTS PASSED"
            severity note;

        wait;
    end process;

end Simulation;
