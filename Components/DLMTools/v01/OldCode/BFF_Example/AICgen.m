%% AICgen.m: Obtain AIC matrix using DLM
% Script to run DLM code developed by UMN UAV group for BFF/mini-MUTT aircraft
% It further calculates the generalized aerodynamics matrix based on the
% structural model of the BFF aircraft
% 
% The functions called are:
%
% 1. getAIC(PanelData,NodeData,Mach,k,S,n_hat_w,n_hat_wl): Calculates aerodynamic
%    influence coefficients matrix (AIC) based on the panels and nodes
%    data, reduced frequency (k) and Mach no. as well as steady aero
%    solutions from VLM
%
% 2. modal_aero(): calculates generalized aerodynamics matrix 
%
% 3. rational_approx(): carries out rational approximation for the
%                       generalized aerodynamics matrices as a function of 
%                        reduced frequency 
%                       A(s) = A0 + sA1 + (s^2)A2 + ss(Alag,Blag,Clag)                             
%
%
% written by: 
% Aditya Kotikalpudi
% Graduate assistant
% University of Minnesota
% % date: 03/23/2014
%
% Modified by: 
% Abhineet Gupta
% Graduate assistant
% University of Minnesota
% Date: 11/22/2017


%% Clear workspace
clear
close all
clc

%% Identify project path
path_main = [pwd,'/'];
path_data = [path_main,'Data_files/'];
Components.path_main = path_main;
Components.path_data = path_data;

addpath([path_main,'../'])

%% Parameters of the code
% Choose if gridding function need to be called.
call_gridfunc = 1;

% Choose if aircraft data function need to be called.
call_aircraftdatafunc = 1;

% Choose if GAM function need to be called.
call_GAMfunc = 1;

if call_gridfunc ==1
    call_GAMfunc = 1;
end

%% Define FEM model
Components.FEM_file = 'Geri_5pdamp';
load([path_data,Components.FEM_file]);

%% Obtain grid information
Components.Grid_file = 'AeroGridData_v01';

if call_gridfunc
    addpath([path_main,'gridding/'])
    griddata = GridData(Components);
else
    load([path_data,Components.Grid_file]);
end

PanelData = griddata.PanelData;
NodeData = griddata.NodeData;
Npanel = griddata.num_of_panels;
PAreas = griddata.PanelArea';
n_hat_w = griddata.n_hat_wingbody;    
n_hat_wl = griddata.n_hat_wl;  

%% Obtain aircraft data
Components.AircraftData_file = 'AircraftData_v02';

if call_aircraftdatafunc
    aircraftdata = AircraftData(Components);
else
    load([path_data,Components.AircraftData_file]);
end

cref = aircraftdata.c;

%% Obtain GAM Data
Components.GAM_file = 'GAM_data_v02';

if call_GAMfunc
    addpath([path_main,'GAM_matrices_BFF/'])
    geom = GAM_matrices(Components);    
else
    load([path_data,Components.GAM_file]);
end

%% get AIC matrices for 8 red freq
k = [0 0.0469 0.0938 0.1875 0.375 0.75 1.5 3];  % freq. considered by DLR
kr = (2/cref)*k;
Mach = 0;
AIC = zeros(Npanel,Npanel,length(k));
for i = 1:length(k)
    AIC(:,:,i) = getAIC(PanelData,NodeData,Mach,kr(i),PAreas,n_hat_w,n_hat_wl);
    disp('1 cycle completed')    
end

% save AIC_VLM AIC



%% get AIC in modal coordinates 
phigh = [modes.PHIg1b modes.PHIg1f];
genAIC_nln = modal_aero(AIC,phigh,griddata.phiCS,geom.Tkg,geom.S,geom.D1,geom.D2,k);


%% Rational Fraction Approximation
b_poles = [0.1100 0.2200];    % lag poles
[A_0,A_1,A_2,A_p,A_lag,B_lag,C_lag] = rational_approx(genAIC_nln,b_poles,k);
aero.RFA_Qhhx_nln.A0 = A_0;
aero.RFA_Qhhx_nln.A1 = A_1;
aero.RFA_Qhhx_nln.A2 = A_2;
aero.RFA_Qhhx_nln.Ap = A_p;
aero.RFA_Qhhx_nln.Alag = A_lag;
aero.RFA_Qhhx_nln.Blag = B_lag;
aero.RFA_Qhhx_nln.Clag = C_lag;
aero.RFA_Qhhx_nln.poles = b_poles;


%% arrange data as required by Simulation
miniMUTT_dyn.aero = aero;
miniMUTT_dyn.geom = geom;
miniMUTT_dyn.modes = modes;


%% Save data in relevant .mat file 
save ('Geri_AIC_5pdamp.mat','miniMUTT_dyn');    