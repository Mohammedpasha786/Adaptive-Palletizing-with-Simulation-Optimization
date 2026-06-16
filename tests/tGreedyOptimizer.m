classdef tGreedyOptimizer < matlab.unittest.TestCase
%TGREEDYOPTIMIZER Unit tests for greedyLayoutHeuristic.m and decodeChromosome.m

    properties (Constant)
        Pallet = struct('length', 1200, 'width', 800, 'maxHeight', 1200, 'maxWeight', 1000)
    end

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testAllSmallBoxesFit(tc)
            n = 6;
            ids = arrayfun(@(k) sprintf('S%d',k), 1:n, 'UniformOutput', false);
            boxes = makeBoxTable(ids, repmat(150,n,1), repmat(100,n,1), repmat(80,n,1), repmat(2,n,1));
            [layout, info] = greedyLayoutHeuristic(boxes, tc.Pallet);
            tc.verifyEqual(info.numUnplaced, 0, 'All small boxes should fit.');
            tc.verifyGreaterThan(info.utilization, 0);
            [ok, issues] = checkLayoutCollisions(layout, tc.Pallet);
            tc.verifyTrue(ok, strjoin(issues, '; '));
        end

        function testOversizedBoxNotPlaced(tc)
            boxes = makeBoxTable({'GIANT'}, 9000, 9000, 200, 50);
            [~, info] = greedyLayoutHeuristic(boxes, tc.Pallet);
            tc.verifyEqual(info.numUnplaced, 1);
        end

        function testRotationOptionFalse(tc)
            boxes = makeBoxTable({'R'}, 500, 300, 100, 5);
            [layout, ~] = greedyLayoutHeuristic(boxes, tc.Pallet, 'AllowRotation', false);
            if layout.placed(1)
                tc.verifyFalse(layout.rotated(1), 'Rotation disabled but box was rotated.');
            end
        end

        function testDecodeChromosomeRoundtrip(tc)
            n = 4;
            ids = arrayfun(@(k) sprintf('C%d',k), 1:n, 'UniformOutput', false);
            boxes = makeBoxTable(ids, repmat(200,n,1), repmat(150,n,1), repmat(100,n,1), repmat(3,n,1));
            x = rand(1, 2*n);
            layout = decodeChromosome(x, boxes, tc.Pallet);
            tc.verifyEqual(height(layout), n, 'Layout must have one row per box.');
            tc.verifyTrue(ismember('placed', layout.Properties.VariableNames));
        end

        function testDecodeChromosomeInvalidLength(tc)
            boxes = makeBoxTable({'X'}, 100, 100, 100, 1);
            tc.verifyError(@() decodeChromosome(rand(1,3), boxes, tc.Pallet), ...
                'decodeChromosome:InvalidLength');
        end
    end
end

function t = makeBoxTable(ids, L, W, H, wt)
    ids = string(ids(:)); L = L(:); W = W(:); H = H(:); wt = wt(:);
    t = table(ids, L, W, H, wt, 'VariableNames', {'id','length','width','height','weight'});
end
