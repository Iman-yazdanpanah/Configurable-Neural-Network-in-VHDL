
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Testbench for our fixed-point adder.
-- A testbench is simulation-only code: it does not become
-- part of the hardware synthesized for the FPGA.

entity fixed_adder_tb is
end fixed_adder_tb;

architecture Simulation of fixed_adder_tb is

    -- Match the default configuration of fixed_adder.
    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;

    -- Signals connect the testbench to the component under test.
    signal a   : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal b   : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal sum : signed(DATA_WIDTH - 1 downto 0);

begin

    -- Instantiate the actual adder design.
    DUT : entity work.fixed_adder
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            a   => a,
            b   => b,
            sum => sum
        );

    -- Apply test inputs one by one.
    
    stimulus : process
    begin
    
        -- Test 1: Ordinary fixed-point addition.
        -- 1.5 + 2.0 = 3.5
        a <= to_signed(768, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert sum = to_signed(1792, DATA_WIDTH)
            report "Test 1 failed: normal addition"
            severity error;
    
        -- Test 2: Positive overflow.
        -- 32760 + 20 = 32780, which exceeds 32767.
        -- The output must saturate at 32767.
        a <= to_signed(32760, DATA_WIDTH);
        b <= to_signed(20, DATA_WIDTH);
        wait for 10 ns;
        assert sum = to_signed(32767, DATA_WIDTH)
            report "Test 2 failed: positive saturation"
            severity error;
    
        -- Test 3: Negative overflow.
        -- -32760 + (-20) = -32780, below -32768.
        -- The output must saturate at -32768.
        a <= to_signed(-32760, DATA_WIDTH);
        b <= to_signed(-20, DATA_WIDTH);
        wait for 10 ns;
        assert sum = to_signed(-32768, DATA_WIDTH)
            report "Test 3 failed: negative saturation"
            severity error;
    
        -- Test 4: Adding zero must preserve the input.
        a <= to_signed(-768, DATA_WIDTH);
        b <= to_signed(0, DATA_WIDTH);
        wait for 10 ns;
        assert sum = to_signed(-768, DATA_WIDTH)
            report "Test 4 failed: adding zero"
            severity error;
    
        report "All saturating adder tests completed successfully."
            severity note;
    
        wait;
    end process;


end Simulation;
