function deconvResponses = deconvolution_HybridWiener_1D(BOLD_signal, distance, ...
                                                        time, params) 
%% deconvolution_HybridWiener_1D.m
%
% Deconvolves the 1D responses using the Hybrid Wiener method described in 
% the paper. The method uses a Wiener deconvolution to get the neural 
% activity phi. The obtained phi is then fed to the hemodynamic model to do 
% a forward calculation of the reconvolved BOLD and other responses.
%
% Inputs: BOLD_signal   : array of 1D BOLD signal (x,t)
%                         size(BOLD_signal) = [length(distance), length(time)]                          
%         distance      : vector of distance to get the 1D BOLD_signal. 
%                         This needs to be symmetric with respect to x = 0 
%                         such that x(1) = -x(end)
%         time          : vector of time to get the 1D BOLD_signal. 
%                         This needs to be symmetric with respect to t = 0 
%                         such that t(1) = -t(end).
%         params        : instance of the class loadParameters of the 
%                         toolbox
%
% Output: deconvResponses    : structure containing the 1D deconvolved responses.
%                         Possible fields are reconvBOLD, neural, neuroglial, 
%                         CBF, CBV, dHb, Wmode, Lmode, and Dmode.
% 
% Example:
% >> params = loadParameters;
% >> load BOLD_signal.mat                 % assuming the BOLD data is stored in this mat file
% >> distance = linspace(-5,5,256)*1e-3;  % in mm
% >> time = linspace(-20,20,256);         % in s
% >> deconvResponses = deconvolution_HybridWiener_1D(BOLD_signal, distance, time, 
%                                               params)
% >> deconvResponses.neural               % gives out the deconvolved
%                                           1D neural activity
% 
% Original: James Pang, University of Sydney, 2016
% Version 1.2: James Pang, University of Sydney, Jan 2018

%%

% calculating computational parameters 
Nkx = length(distance);
Nw = length(time);
kxsamp = (1/mean(diff(distance)))*2*pi;
wsamp = (1/mean(diff(time)))*2*pi;

% creating vectors of frequencies kx and w
[kx, w] = generate_kw_1D(kxsamp, wsamp, Nkx, Nw);

% calculate 1D transfer function to Y
% T is a structure with possible fields: T_Yphi, T_Yz, T_YF, T_YXi, T_YQ, 
% T_Y1, T_Y2, T_Y3, T_Y4, T_Y5, T_YW, T_YL, and T_YD.
T = calcTransFuncs_toY_1D(kx, w, params);


% deconvolve 1D neural activity using a Wiener filter
% Note for the noise input for the wienerDeconvolution_1D function:
% 1. It is the NSR term in the paper and can either be a single number or a 
%    1x2 vector. 
%       * If it is a single number, the assumption is that we have a white 
%         noise with constant amplitude sigma. 
%       * If it is 1x2 vector, the assumption is that we're using cut-off
%         frequencies, where noise(1) is the spatial cut-off frequency and 
%         noise(2) is the temporal cut-off frequency.
% 2. For now, it's a constant in loadParameters. Change it according to your 
%    intelligible choice.
noise = params.noise;
deconvolved_neural = wienerDeconvolution_1D(BOLD_signal, T.T_Yphi, kx, w, noise);
deconvResponses.('neural') = real(deconvolved_neural.coord);


% calculate 1D transfer function from phi
% T2 is a structure with possible fields: T_Yphi, T_zphi, T_Fphi, T_Xiphi, 
% T_Qphi, T_1phi, T_2phi, T_3phi, T_4phi, T_5phi, T_Wphi, T_Lphi, and T_Dphi.
T2 = calcTransFuncs_fromPhi_1D(kx, w, params);


% deconvolve 1D responses using a forward calculation  
names = {'reconvBOLD', 'neuroglial', 'CBF', 'CBV', 'dHb', 'Wmode', 'Lmode', 'Dmode'};
variables = {'Y', 'z', 'F', 'Xi', 'Q', 'W', 'L', 'D'};
for i=1:length(variables)
    trans_func = ['T2.T_', variables{i}, 'phi'];
    deconvResponses.(names{i}) = real(freq2coord_1D(eval(trans_func).*deconvolved_neural.freq, ...
                            kx, w));
end
