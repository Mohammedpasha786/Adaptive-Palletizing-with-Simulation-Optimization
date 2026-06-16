classdef tPerceptionBuffer < matlab.unittest.TestCase
%TPERCEPTIONBUFFER Unit tests for PerceptionBuffer.m, simulateBoxDetection.m, generateBoxID.m

    methods (TestMethodSetup)
        function addPaths(tc) %#ok<MANU>
            addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src')));
        end
    end

    methods (Test)
        function testBufferNotReadyBelowThreshold(tc)
            buf = PerceptionBuffer('ReadyThreshold', 5);
            for k = 1:4
                buf.addBox(simulateBoxDetection(1, 'Seed', k));
            end
            tc.verifyFalse(buf.isReady());
            tc.verifyEqual(buf.count(), 4);
        end

        function testBufferReadyAtThreshold(tc)
            buf = PerceptionBuffer('ReadyThreshold', 3);
            for k = 1:3
                buf.addBox(simulateBoxDetection(1, 'Seed', k));
            end
            tc.verifyTrue(buf.isReady());
        end

        function testFlushClearsBuffer(tc)
            buf = PerceptionBuffer('ReadyThreshold', 2);
            buf.addBox(simulateBoxDetection(1, 'Seed', 1));
            buf.addBox(simulateBoxDetection(1, 'Seed', 2));
            batch = buf.flush();
            tc.verifyEqual(height(batch), 2);
            tc.verifyEqual(buf.count(), 0);
            tc.verifyFalse(buf.isReady());
        end

        function testSimulateBoxDetectionSchema(tc)
            boxes = simulateBoxDetection(5, 'Seed', 99);
            tc.verifyEqual(height(boxes), 5);
            expected = {'id','length','width','height','weight'};
            tc.verifyTrue(all(ismember(expected, boxes.Properties.VariableNames)));
            tc.verifyTrue(all(boxes.length > 0));
            tc.verifyTrue(all(boxes.weight > 0));
        end

        function testSimulateBoxDetectionSeedReproducible(tc)
            b1 = simulateBoxDetection(3, 'Seed', 42);
            b2 = simulateBoxDetection(3, 'Seed', 42);
            tc.verifyEqual(b1.length, b2.length, 'AbsTol', 1e-9, 'Same seed must produce same dimensions.');
        end

        function testGenerateBoxIDFormat(tc)
            id = generateBoxID();
            tc.verifyTrue(startsWith(id, 'BOX-'), 'Default prefix should be "BOX-".');
        end

        function testGenerateBoxIDCustomPrefix(tc)
            id = generateBoxID('Prefix', 'PAL', 'NumDigits', 4);
            tc.verifyTrue(startsWith(id, 'PAL-'));
        end
    end
end
