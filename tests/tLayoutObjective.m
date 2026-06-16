classdef tLayoutObjective < matlab.unittest.TestCase
%TLAYOUTOBJECTIVE Unit tests for layoutObjective.m

    properties (Constant)
        Pallet = struct('length', 1000, 'width', 500, 'maxHeight', 1000, 'maxWeight', 500)
    end

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testFullPalletCostNearMinusOne(tc)
            % One box perfectly filling the pallet, no unplaced boxes.
            boxes = table("B1", 1000, 500, 200, 10, ...
                'VariableNames', {'id','length','width','height','weight'});
            layout = shelfPack(boxes, 1, false, tc.Pallet, 0);
            [cost, info] = layoutObjective(layout, tc.Pallet);
            tc.verifyEqual(cost, -1.0, 'AbsTol', 1e-9, 'Full pallet should give cost ≈ -1.');
            tc.verifyEqual(info.utilization, 1.0, 'AbsTol', 1e-9);
            tc.verifyEqual(info.numUnplaced, 0);
        end

        function testUnplacedBoxIncreasesCoast(tc)
            % Tiny box placed + giant box cannot fit → penalty applied.
            boxes = table(["B1";"B2"], [100;5000], [100;5000], [50;50], [1;1], ...
                'VariableNames', {'id','length','width','height','weight'});
            layout = shelfPack(boxes, [1 2], false(2,1), tc.Pallet, 0);
            [cost, info] = layoutObjective(layout, tc.Pallet, 2);
            tc.verifyGreaterThan(cost, 0, 'Unplaced box should push cost positive.');
            tc.verifyEqual(info.numUnplaced, 1);
        end

        function testEmptyLayoutCostIsZero(tc)
            boxes = table(string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
                'VariableNames', {'id','length','width','height','weight'});
            layout = shelfPack(boxes, [], logical([]), tc.Pallet, 0);
            [cost, info] = layoutObjective(layout, tc.Pallet);
            tc.verifyEqual(cost, 0, 'AbsTol', 1e-9);
            tc.verifyEqual(info.utilization, 0, 'AbsTol', 1e-9);
        end
    end
end
