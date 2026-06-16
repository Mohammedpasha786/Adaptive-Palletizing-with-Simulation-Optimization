classdef tRrtPlanner < matlab.unittest.TestCase
%TRRTPLANNER Unit tests for rrtPlanner.m, checkPathCollisionFree.m, layoutToObstacles.m

    properties (Constant)
        Workspace = struct('min', [0 0 0], 'max', [1200 800 1500])
        Home      = [0 0 1400]
    end

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testFreeSpacePlanSucceeds(tc)
            goal = [600 400 300];
            [path, info] = rrtPlanner(tc.Home, goal, struct([]), tc.Workspace, ...
                'MaxIterations', 3000, 'GoalTolerance', 30);
            tc.verifyTrue(info.success, 'RRT should find a path in free space.');
            tc.verifyGreaterThan(size(path, 1), 1);
        end

        function testStartEqualsGoalSucceeds(tc)
            pt = [600 400 800];
            [path, info] = rrtPlanner(pt, pt, struct([]), tc.Workspace, ...
                'GoalTolerance', 30);
            tc.verifyTrue(info.success);
            tc.verifyFalse(isempty(path));
        end

        function testInvalidEndpointErrors(tc)
            obs(1).min = [0 0 0]; obs(1).max = [1200 800 1500];
            tc.verifyError( ...
                @() rrtPlanner(tc.Home, [600 400 300], obs, tc.Workspace), ...
                'rrtPlanner:InvalidEndpoint');
        end

        function testCheckPathFreeInFreeSpace(tc)
            path = [0 0 0; 600 400 800; 1200 800 1400];
            [isFree, firstSeg] = checkPathCollisionFree(path, struct([]), 10);
            tc.verifyTrue(isFree);
            tc.verifyEqual(firstSeg, 0);
        end

        function testCheckPathBlockedByObstacle(tc)
            obs(1).min = [400 300 0]; obs(1).max = [800 500 1500];
            path = [0 0 800; 1200 800 800]; % passes through the obstacle
            [isFree, ~] = checkPathCollisionFree(path, obs, 20);
            tc.verifyFalse(isFree);
        end

        function testLayoutToObstaclesCount(tc)
            boxes = makeBoxTable({'A','B','C'}, [300;300;300], [200;200;200], [100;100;100], [4;4;4]);
            pallet = struct('length',1200,'width',800,'maxHeight',1200,'maxWeight',1000);
            layout = shelfPack(boxes, [1 2 3], false(3,1), pallet, 0);
            placedCount = sum(layout.placed);
            obstacles = layoutToObstacles(layout, 0);
            tc.verifyEqual(numel(obstacles), placedCount);
        end
    end
end

function t = makeBoxTable(ids, L, W, H, wt)
    ids = string(ids(:)); L = L(:); W = W(:); H = H(:); wt = wt(:);
    t = table(ids, L, W, H, wt, 'VariableNames', {'id','length','width','height','weight'});
end
