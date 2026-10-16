
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity neuron_tb is
end neuron_tb;

architecture Behavioral of neuron_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_INPUTS   : positive := 2;
    constant ACC_WIDTH  : positive := 40;

    -- Each input/weight uses 16 bits.
    -- Two values are packed into a 32-bit vector.
    signal inputs  : STD_LOGIC_VECTOR(N_INPUTS * DATA_WIDTH - 1 downto 0)
                     := (others => '0');

    signal weights : STD_LOGIC_VECTOR(N_INPUTS * DATA_WIDTH - 1 downto 0)
                     := (others => '0');

    signal bias   : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal result : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    -- Instantiate the neuron using its actual port names.
    uut : entity work.neuron
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            ACC_WIDTH  => ACC_WIDTH
        )
        port map (
            inputs  => inputs,
            weights => weights,
            bias    => bias,
            result  => result
        );

    stimulus : process
    begin

        --------------------------------------------------
        -- TEST 1:
        -- x1 = 1.0, x2 = 2.0
        -- w1 = 2.0, w2 = 1.0
        -- bias = 0
        -- Expected: ReLU(1*2 + 2*1) = 4.0
        -- Fixed-point representation: 4 * 512 = 2048
        --------------------------------------------------

        -- Input 0 occupies bits 15 downto 0.
        -- Input 1 occupies bits 31 downto 16.
        inputs(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));
        inputs(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));

        -- Pack the corresponding weights in the same order.
        weights(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));
      
        weights(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        bias <= to_signed(0, DATA_WIDTH);

        wait for 10 ns;

        assert result = to_signed(2048, DATA_WIDTH)
            report "TEST 1 FAILED: Expected 2048 (4.0)"
            severity error;


        --------------------------------------------------
        -- TEST 2:
        -- x1 = 1.0, x2 = 1.0
        -- w1 = -2.0, w2 = -1.0
        -- bias = 0
        -- Pre-ReLU result = -3.0
        -- Expected after ReLU = 0
        --------------------------------------------------

        inputs(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));
        inputs(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        weights(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(-1024, DATA_WIDTH));
        weights(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(-512, DATA_WIDTH));

        bias <= to_signed(0, DATA_WIDTH);

        wait for 10 ns;

        assert result = to_signed(0, DATA_WIDTH)
            report "TEST 2 FAILED: ReLU should output zero"
            severity error;


        --------------------------------------------------
        -- TEST 3:
        -- Inputs = 0, bias = 1.5
        -- Expected output = 1.5
        -- Fixed-point representation: 1.5 * 512 = 768
        --------------------------------------------------

        inputs <= (others => '0');

        weights(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));
        weights(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        bias <= to_signed(768, DATA_WIDTH);

        wait for 10 ns;

        assert result = to_signed(768, DATA_WIDTH)
            report "TEST 3 FAILED: Expected 768 (1.5)"
            severity error;


        report "All neuron tests completed successfully."
            severity note;

        wait;
    end process;

end Behavioral;
