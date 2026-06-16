classdef tShelfPack < matlab.unittest.TestCase
%TSHELFPACK Unit tests for shelfPack.m

    properties (Constant)
        Pallet = struct('length', 1200, 'width', 800, 'maxHeight', 1200, 'maxWeight', 1000)
    end

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testSingleBoxFits(tc)
            boxes = makeBoxTable({'B1'}, 300, 200, 150, 5);
            layout = shelfPack(boxes, 1, false, tc.Pallet, 0);
            tc.verifyTrue(layout.placed(1), 'Single box should be placed.');
            tc.verifyEqual(layout.x(1), 0, 'Box should start at x=0.');
            tc.verifyEqual(layout.y(1), 0, 'Box should start at y=0.');
        end

        function testBoxTooLargeNotPlaced(tc)
            boxes = makeBoxTable({'HUGE'}, 2000, 2000, 500, 50);
            layout = shelfPack(boxes, 1, false, tc.Pallet, 0);
            tc.verifyFalse(layout.placed(1), 'Oversized box must not be placed.');
            tc.verifyTrue(isnan(layout.x(1)), 'x must be NaN for unplaced box.');
        end

        function testMultipleBoxesNoOverlap(tc)
            n = 5;
            ids = arrayfun(@(k) sprintf('B%d',k), 1:n, 'UniformOutput', false);
            boxes = makeBoxTable(ids, repmat(200,n,1), repmat(150,n,1), repmat(100,n,1), repmat(3,n,1));
            layout = shelfPack(boxes, 1:n, false(n,1), tc.Pallet, 0);
            placed = find(layout.placed);
            for a = 1:numel(placed)
                for b = a+1:numel(placed)
                    i = placed(a); j = placed(b);
                    if abs(layout.z(i) - layout.z(j)) < 1e-6
                        overlapX = layout.x(i) < layout.x(j)+layout.placedLength(j) && ...
                                   layout.x(j) < layout.x(i)+layout.placedLength(i);
                        overlapY = layout.y(i) < layout.y(j)+layout.placedWidth(j) && ...
                                   layout.y(j) < layout.y(i)+layout.placedWidth(i);
                        tc.verifyFalse(overlapX && overlapY, ...
                            sprintf('Boxes %d and %d overlap.', i, j));
                    end
                end
            end
        end

        function testRotation(tc)
            % A 700x100 box should NOT fit width-first (100 < 800 ok, length 700 < 1200 ok)
            % but try with rotated = true → placedLength = 100, placedWidth = 700
            boxes = makeBoxTable({'R1'}, 700, 100, 50, 1);
            layout = shelfPack(boxes, 1, true, tc.Pallet, 0);
            tc.verifyTrue(layout.placed(1));
            tc.verifyEqual(layout.placedLength(1), 100, 'AbsTol', 1e-9);
            tc.verifyEqual(layout.placedWidth(1),  700, 'AbsTol', 1e-9);
        end

        function testZOffset(tc)
            boxes = makeBoxTable({'B1'}, 300, 200, 100, 4);
            layout = shelfPack(boxes, 1, false, tc.Pallet, 250);
            tc.verifyEqual(layout.z(1), 250, 'AbsTol', 1e-9, 'z-offset not applied.');
        end

        function testEmptyInput(tc)
            boxes = makeBoxTable({}, [], [], [], []);
            layout = shelfPack(boxes, [], logical([]), tc.Pallet, 0);
            tc.verifyEqual(height(layout), 0);
        end
    end
end

function t = makeBoxTable(ids, L, W, H, wt)
    ids = string(ids(:)); L = L(:); W = W(:); H = H(:); wt = wt(:);
    t = table(ids, L, W, H, wt, 'VariableNames', {'id','length','width','height','weight'});
end
