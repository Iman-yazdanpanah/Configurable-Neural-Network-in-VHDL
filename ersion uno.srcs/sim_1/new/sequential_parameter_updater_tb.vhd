
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sequential_parameter_updater_tb is
end sequential_parameter_updater_tb;

architecture Behavioral of sequential_parameter_updater_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural := 9;
    constant GRAD_WIDTH : positive := 32;
    constant N_WEIGHTS  : positive := 2;
    constant N_BIASES   : positive := 1;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal start : STD_LOGIC := '0';

    signal learning_rate : SIGNED(15 downto 0)
        := to_signed(5, 16);

    signal gradients : STD_LOGIC_VECTOR(95 downto 0)
        := (others => '0');

    -- Updater read interface
    signal updater_read_address : integer range 0 to 2;
    signal read_data : SIGNED(15 downto 0);

    -- Independent testbench readback interface
    signal readback_mode : STD_LOGIC := '0';
    signal readback_address : integer range 0 to 2 := 0;
    signal memory_read_address : integer range 0 to 2;

    -- Updater write interface
    signal updater_write_enable : STD_LOGIC;
    signal updater_write_address : integer range 0 to 2;
    signal updater_write_data : SIGNED(15 downto 0);

    -- Initialization write interface
    signal init_mode : STD_LOGIC := '1';
    signal init_write_enable : STD_LOGIC := '0';
    signal init_write_address : integer range 0 to 2 := 0;
    signal init_write_data : SIGNED(15 downto 0)
        := (others => '0');

    -- Selected memory write interface
    signal actual_write_enable : STD_LOGIC;
    signal actual_write_address : integer range 0 to 2;
    signal actual_write_data : SIGNED(15 downto 0);

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

begin

    clk <= not clk after 5 ns;

    -- Select initialization writes or updater writes.
    actual_write_enable <= init_write_enable
        when init_mode = '1'
        else updater_write_enable;

    actual_write_address <= init_write_address
        when init_mode = '1'
        else updater_write_address;

    actual_write_data <= init_write_data
        when init_mode = '1'
        else updater_write_data;

    -- Select updater reads during training or testbench reads afterward.
    memory_read_address <= readback_address
        when readback_mode = '1'
        else updater_read_address;

    MEMORY : entity work.parameter_access
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk           => clk,
            write_enable  => actual_write_enable,
            write_address => actual_write_address,
            write_data    => actual_write_data,
            read_address  => memory_read_address,
            read_data     => read_data
        );

    DUT : entity work.sequential_parameter_updater
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            GRAD_WIDTH => GRAD_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            clk => clk,
            reset => reset,
            start => start,
            learning_rate => learning_rate,
            gradients => gradients,

            memory_read_address => updater_read_address,
            memory_read_data => read_data,

            memory_write_enable => updater_write_enable,
            memory_write_address => updater_write_address,
            memory_write_data => updater_write_data,

            busy => busy,
            done => done
        );

    stimulus : process
    begin

        ------------------------------------------------------------
        -- TEST SETUP: RESET
        ------------------------------------------------------------
        wait for 12 ns;
        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        ------------------------------------------------------------
        -- Initialize weight 0 = 1024
        ------------------------------------------------------------
        init_write_enable <= '1';
        init_write_address <= 0;
        init_write_data <= to_signed(1024, 16);

        wait until rising_edge(clk);
        wait for 1 ns;

        ------------------------------------------------------------
        -- Initialize weight 1 = 512
        ------------------------------------------------------------
        init_write_address <= 1;
        init_write_data <= to_signed(512, 16);

        wait until rising_edge(clk);
        wait for 1 ns;

        ------------------------------------------------------------
        -- Initialize bias 0 = 2048
        ------------------------------------------------------------
        init_write_address <= 2;
        init_write_data <= to_signed(2048, 16);

        wait until rising_edge(clk);
        wait for 1 ns;

        init_write_enable <= '0';
        init_mode <= '0';

        ------------------------------------------------------------
        -- Gradients: 512, 1024, 512
        ------------------------------------------------------------
        gradients(31 downto 0) <=
            std_logic_vector(to_signed(512, 32));

        gradients(63 downto 32) <=
            std_logic_vector(to_signed(1024, 32));

        gradients(95 downto 64) <=
            std_logic_vector(to_signed(512, 32));

        -- Learning rate = 5 / 512.
        learning_rate <= to_signed(5, 16);

        wait until rising_edge(clk);
        wait for 1 ns;

        ------------------------------------------------------------
        -- Start sequential update
        ------------------------------------------------------------
        start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';

        ------------------------------------------------------------
        -- Wait for updater completion
        ------------------------------------------------------------
        wait until done = '1';
        wait for 1 ns;

        assert busy = '0'
            report "TEST FAILED: busy should be low after completion"
            severity failure;

        report "TEST PASSED: updater completed"
            severity note;

        ------------------------------------------------------------
        -- Switch memory reads to the testbench
        ------------------------------------------------------------
        readback_mode <= '1';

        ------------------------------------------------------------
        -- TEST 1: Weight 0 = 1024 - 5 = 1019
        ------------------------------------------------------------
        readback_address <= 0;
        wait for 1 ns;

        assert read_data = to_signed(1019, 16)
            report "TEST 1 FAILED: weight 0 is not 1019"
            severity failure;

        report "TEST 1 PASSED: weight 0 = 1019"
            severity note;

        ------------------------------------------------------------
        -- TEST 2: Weight 1 = 512 - 10 = 502
        ------------------------------------------------------------
        readback_address <= 1;
        wait for 1 ns;

        assert read_data = to_signed(502, 16)
            report "TEST 2 FAILED: weight 1 is not 502"
            severity failure;

        report "TEST 2 PASSED: weight 1 = 502"
            severity note;

        ------------------------------------------------------------
        -- TEST 3: Bias 0 = 2048 - 5 = 2043
        ------------------------------------------------------------
        readback_address <= 2;
        wait for 1 ns;

        assert read_data = to_signed(2043, 16)
            report "TEST 3 FAILED: bias 0 is not 2043"
            severity failure;

        report "TEST 3 PASSED: bias 0 = 2043"
            severity note;

        ------------------------------------------------------------
        -- ALL TESTS PASSED
        ------------------------------------------------------------
        report "ALL SEQUENTIAL UPDATER TESTS PASSED"
            severity note;

        wait;
    end process;

end Behavioral;
