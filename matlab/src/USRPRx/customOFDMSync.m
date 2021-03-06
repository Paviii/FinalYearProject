classdef customOFDMSync < matlab.System

% Copyright 2015-2017 The MathWorks, Inc.

%#codegen

properties (Nontunable)
    ChannelBandwidth = 'CBW20';
    SymbolTimingThreshold = 1;
    OFDMSymbolOffset = .75;
    numOfDataSymbols = 100;
end

properties (Access = private, Nontunable)
    pAGC
    pCoarseFreqCompensator
    pFineFreqCompensator
    pSyncSymbolBuffer
    pSymbolLen    
end

properties (Access = private)
    % Packet detection related 
    pPacketDetected
    pLSTFSearchBuffer
    pTimingSynced
    % Symbol timing related
    pLSIGDecoded
    pLLTFSearchBuffer
    pLLTFBufferedSymbols
    pTimingOffset
    % CFO related
    pCoarseCFOEst
    pFineCFOEst
    % L-SIG decoding related
    pCfgRec
    pLSIGSym
    pSeqNum
    % PSDU decoding related    
    pFullPayload
    pNumCollectedDataSym
    % Output related
    pChanEst
    pCfgNonHT
    pNoiseVarEst
end

properties (Constant, Hidden)
  ChannelBandwidthSet = matlab.system.StringSet({'CBW20', 'CBW40', 'CBW80', 'CBW160'});
end

methods
  function obj = customOFDMSync(varargin)
    setProperties(obj,nargin,varargin{:});
  end
  
  function set.SymbolTimingThreshold(obj, val)
    prop = 'SymbolTimingThreshold';
    validateattributes(val, {'double'}, ...
        {'real','scalar','>=',0,'<=',1}, ...
        [class(obj) '.' prop], prop);
    obj.(prop) = val;
  end
  
  function set.OFDMSymbolOffset(obj, val)
    prop = 'OFDMSymbolOffset';
    validateattributes(val, {'double'}, ...
        {'real','scalar','>=',0,'<=',1}, ...
        [class(obj) '.' prop], prop);
    obj.(prop) = val;
  end
  
  function set.numOfDataSymbols(obj, val)
    prop = 'numOfDataSymbols';
    validateattributes(val, {'double'}, ...
        {'real','scalar','>=',0}, ...
        [class(obj) '.' prop], prop);
    obj.(prop) = val;
  end
  
end

methods (Access = protected)
  function validateInputsImpl(~, x)
    validateattributes(x, {'double'}, {'column','finite'}, 'step', 'X');
  end

  function setupImpl(obj)
    Rs = wlan.internal.cbwStr2Num(obj.ChannelBandwidth)*1e6;
    obj.pSymbolLen = 4*Rs/1e6;

    % Instantiate objects
    obj.pAGC = comm.AGC('AveragingLength',obj.numOfDataSymbols*10);

    obj.pCoarseFreqCompensator = comm.PhaseFrequencyOffset( ...
        'FrequencyOffsetSource', 'Input port', ...
        'SampleRate',            Rs);

    obj.pFineFreqCompensator = comm.PhaseFrequencyOffset( ...
        'FrequencyOffsetSource', 'Input port', ...
        'SampleRate',            Rs);

    obj.pSyncSymbolBuffer = dsp.VariableIntegerDelay( ... 
        'MaximumDelay',      obj.pSymbolLen, ...
        'DirectFeedthrough', true);

    obj.pCfgRec = wlanRecoveryConfig( ...
        'OFDMSymbolOffset',   obj.OFDMSymbolOffset, ...
        'EqualizationMethod', 'ZF'); % Set to zero-forcing
    
    obj.pCfgNonHT = wlanNonHTConfig;
  end

  function resetImpl(obj)
    % Initialize some scalar variables
    obj.pLLTFBufferedSymbols = 0;
    obj.pTimingOffset        = 0;
    obj.pCoarseCFOEst        = 0;
    obj.pFineCFOEst          = 0;    
    obj.pNumCollectedDataSym = 0;
    obj.pNoiseVarEst         = 0; 
    obj.pSeqNum              = 0;
    
    % Initialize flags for modes
    obj.pPacketDetected = false;
    obj.pTimingSynced   = false;
    obj.pLSIGDecoded    = false;
      
    % Initialize buffers and states
    obj.pLSTFSearchBuffer = complex(zeros(2*obj.pSymbolLen, 1));
    obj.pLLTFSearchBuffer = complex(zeros(4*obj.pSymbolLen, 1));    
    obj.pFullPayload      = complex(0);
    obj.pChanEst          = complex(0);
    
    % Reset System objects
    reset(obj.pAGC);
    reset(obj.pCoarseFreqCompensator);
    reset(obj.pFineFreqCompensator);
    reset(obj.pSyncSymbolBuffer);
  end
  
  function [validPacket, cfgSig, rxData, chanEst, noiseVarEst, seqNum, data ] = stepImpl(obj, x)    
    % Output initialization
    validPacket = false;
    cfgSig    = obj.pCfgNonHT;
    rxData = complex(0);
    chanEst     = complex(0);
    noiseVarEst = 0;
    seqNum = 0;
    
    % Parameters
    chanBW = obj.ChannelBandwidth;
    symLen = obj.pSymbolLen;
    numSym = floor(length(x)/symLen); % Number of symbols in input
    LLTFStartIndex = 2*obj.pSymbolLen + 1; % LSTF is 2 symbols
    
    for symIdx = 1:numSym % Process input symbol-by-symbol
        data = x((symIdx-1)*symLen + (1:symLen));
        
        % Keep updating L-STF search buffer in case of early failure
        obj.pLSTFSearchBuffer = [obj.pLSTFSearchBuffer(symLen+1:end); data];
        
        if ~obj.pPacketDetected % Packet Detect
            pktOffset = wlanPacketDetect(obj.pLSTFSearchBuffer + 0.0005*(randn(160,1) + 1i*randn(160,1)), chanBW,0,0.5);           
            
            if ~isempty(pktOffset) && (pktOffset(1) <= symLen)
                % Estimate CFO when more than one L-STF symbol in buffer
                obj.pCoarseCFOEst = real(wlanCoarseCFOEstimate( ...
                    obj.pLSTFSearchBuffer(1+pktOffset(1):end,:), chanBW));
                
                % Switch to symbol timing mode
                obj.pPacketDetected     = true;                
                obj.pTimingSynced       = false;
                obj.pLLTFSearchBuffer   = complex(zeros(size(obj.pLLTFSearchBuffer)));
                obj.pLLTFBufferedSymbols = 0;
            end
        else
            % AGC
            %data = obj.pAGC(data);
            
            % Coarse frequency offset compensator
            data = obj.pCoarseFreqCompensator(data, -obj.pCoarseCFOEst);
            
            if ~obj.pTimingSynced % Symbol timing
                % Update L-LTF search buffer
                obj.pLLTFBufferedSymbols = obj.pLLTFBufferedSymbols + 1;
                obj.pLLTFSearchBuffer((obj.pLLTFBufferedSymbols-1)*symLen ...
                    + (1:symLen), :) = data;
                LLTFStart = wlanSymbolTimingEstimate(obj.pLLTFSearchBuffer, ...
                    chanBW, obj.SymbolTimingThreshold) + LLTFStartIndex;
                
                LLTFLen = 2*symLen;
                % The whole L-LTF is in the buffer
                if  obj.pLLTFBufferedSymbols*symLen - LLTFStart(1) + 1 >= LLTFLen

                    % Extract L-LTF
                    LLTF = obj.pLLTFSearchBuffer(LLTFStart(1):LLTFStart(1)+LLTFLen-1);

                    % Fine frequency offset compensator
                    obj.pFineCFOEst = real(wlanFineCFOEstimate(LLTF, chanBW));
                    LLTF(1:end/2) = obj.pFineFreqCompensator( ...
                        LLTF(1:symLen), -obj.pFineCFOEst);
                    LLTF(end/2+1:end) = obj.pFineFreqCompensator( ...
                        LLTF(symLen+(1:symLen)), -obj.pFineCFOEst);

                    % Channel estimation
                    demodLLTF = wlanLLTFDemodulate(LLTF*1.439761298433433, chanBW); %the LTF is scale due to scale in TX
                    obj.pChanEst = wlanLLTFChannelEstimate(demodLLTF, chanBW); 
                    
                    % Estimate noise power using L-LTF field
                    obj.pNoiseVarEst = helperNoiseEstimate(demodLLTF);
                    
                    % Extract L-SIG samples, if any, from L-LTF search buffer
                    leftLSIGSamp = obj.pLLTFSearchBuffer(LLTFStart(1)+LLTFLen:obj.pLLTFBufferedSymbols*symLen);
                    obj.pTimingOffset = size(leftLSIGSamp, 1);

                    % Perform symbol synchronization
                    symSyncInput = [complex(zeros(symLen-obj.pTimingOffset, 1)); ...
                        leftLSIGSamp(1:obj.pTimingOffset,:)];
                    obj.pSyncSymbolBuffer(complex(symSyncInput(1:symLen,:)), obj.pTimingOffset);                        

                    % Switch to data buffering
                    obj.pTimingSynced = true;
                    obj.pLSIGDecoded = false;
                    
                elseif obj.pLLTFBufferedSymbols == 4 
                    % Symbol timing failed -- switch back to packet detection 
                    obj.pPacketDetected = false;
                    obj.pTimingSynced = false;
                end
            else % L-SIG decoding and PSDU buffering
                % Perform symbol synchronization
                syncedSym = obj.pSyncSymbolBuffer(complex(data), obj.pTimingOffset);                
                % Fine frequency offset compensator
                syncedSym(1:symLen,:) = obj.pFineFreqCompensator(syncedSym(1:symLen,:), -obj.pFineCFOEst);

                if ~obj.pLSIGDecoded % L-SIG decoding
                     [LSIGBits, failParityCheck] = wlanLSIGRecover(...
                         syncedSym, obj.pChanEst, obj.pNoiseVarEst, chanBW, obj.pCfgRec);
                     obj.pLSIGSym = syncedSym; % Buffer for format detection
                     
                     % L-SIG evaluation
                     if ~failParityCheck
                         obj.pSeqNum = bi2de(double(LSIGBits(6:17)'));
                         if (obj.pSeqNum > 100)
                             obj.pPacketDetected = false;
                         else 
                             % Switch to PSDU buffering mode
                             obj.pLSIGDecoded = true;
                             obj.pFullPayload = complex(zeros(obj.numOfDataSymbols*symLen, 1));
                             obj.pNumCollectedDataSym = 0;
                         end
                                              
                           
%                         % Recover packet parameters
%                         rate = bi2de(double(LSIGBits(1:3).'), 'left-msb');
%                         if rate <= 1
%                             obj.pCfgNonHT.MCS = rate + 6;
%                         else
%                             obj.pCfgNonHT.MCS = mod(rate, 6);
%                         end                    
%                         obj.pCfgNonHT.PSDULength = bi2de(double(LSIGBits(6:17)'));
% 
%                         % Obtain number of OFDM symbols in data field
%                         obj.pNumDataSymbols = getNumDataSymbols(obj);
%                         

                     else % L-SIG parity failed -- switch back to packet detection 
                         obj.pPacketDetected = false;
                     end
                 else 
                    % PSDU buffering
                    % Keep buffering payload
                                        
                    obj.pCfgNonHT.PSDULength = obj.numOfDataSymbols;
                    obj.pNumCollectedDataSym = obj.pNumCollectedDataSym + 1;
                    obj.pFullPayload((obj.pNumCollectedDataSym-1)*symLen+(1:symLen), :) = syncedSym(1:symLen, :);                   
                    
                    if obj.pNumCollectedDataSym == obj.numOfDataSymbols
                        % Output when payload is full
                        validPacket = true;
                        cfgSig    = obj.pCfgNonHT;
                        rxData = obj.pFullPayload(1:obj.numOfDataSymbols*symLen, :);
                        chanEst     = obj.pChanEst;
                        noiseVarEst = obj.pNoiseVarEst;
                        seqNum = obj.pSeqNum;
                        
                        
                        % Switch back to packet detection
                        obj.pPacketDetected = false;
                    end
                end
            end 
        end 
    end 
  end
  
  function flag = isInputComplexityLockedImpl(~,~)
    flag = false;
  end
  
  function releaseImpl(obj)
    % Release System objects
    release(obj.pAGC);
    release(obj.pCoarseFreqCompensator);
    release(obj.pFineFreqCompensator);
    release(obj.pSyncSymbolBuffer);
  end
  
end

end
