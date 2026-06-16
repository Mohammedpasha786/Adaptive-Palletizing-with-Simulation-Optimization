classdef tChompSmooth < matlab.unittest.TestCase
%TCHOMPSMOOTH Unit tests for chompSmooth.m

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testOutputHasCorrectNumWaypoints(tc)
            path = [0 0 0; 500 0 0; 1000 0 0];
            [smoothPath, ~] = chompSmooth(path, struct([]), 'NumWaypoints', 15, 'Iterations', 10);
            tc.verifyEqual(size(smoothPath, 1), 15);
            tc.verifyEqual(size(smoothPath, 2), 3);
        end

        function testEndpointsPreserved(tc)
            path = [0 0 0; 600 400 800; 1200 800 1400];
            [smoothPath, ~] = chompSmooth(path, struct([]), 'NumWaypoints', 20, 'Iterations', 20);
            tc.verifyEqual(smoothPath(1,:),   path(1,:),   'AbsTol', 1e-6);
            tc.verifyEqual(smoothPath(end,:), path(end,:), 'AbsTol', 1e-6);
        end

        function testSingleSegmentPath(tc)
            path = [0 0 0; 100 100 100];
            [smoothPath, info] = chompSmooth(path, struct([]), 'NumWaypoints', 5, 'Iterations', 5);
            tc.verifyEqual(size(smoothPath,1), 5);
            tc.verifyGreaterThanOrEqual(info.finalCost, 0);
        end

        function testSinglePointPath(tc)
            path = [300 300 300];
            [smoothPath, info] = chompSmooth(path, struct([]), 'NumWaypoints', 5);
            tc.verifyEqual(size(smoothPath, 1), 5);
            tc.verifyEqual(info.iterations, 0);
        end
    end
end
