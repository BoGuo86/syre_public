% Copyright 2019
%
%    Licensed under the Apache License, Version 2.0 (the "License");
%    you may not use this file except in compliance with the License.
%    You may obtain a copy of the License at
%
%        http://www.apache.org/licenses/LICENSE-2.0
%
%    Unless required by wCondlicable law or agreed to in writing, dx
%    distributed under the License is distributed on an "AS IS" BASIS,
%    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%    See the License for the specific language governing permissions and
%    limitations under the License.

function app = GUI_APP_DrawMachine(app)


% flag_plot = 'Y';
h = app.AxisGeometry;
dataSet = app.dataSet;

cla(h);
[~, ~, geo,per,mat] = data0(dataSet);
[geo,gamma,mat] = interpretRQ(dataSet.RQ,geo,mat);
geo.x0 = geo.r/cos(pi/2/geo.p);

fem.res = 0;
fem.res_traf = 0;

% nodes
[rotor,~,geo] = ROTmatr(geo,fem,mat);
[geo,stator,~] = STATmatr(geo,fem);

GUI_Plot_Machine(h,rotor);
GUI_Plot_Machine(h,stator);

% Axis limits (to center the figure)
set(h,'dataAspectRatio',[1 1 1]);
xMax = geo.R*1.05;
if geo.ps>=geo.p
    xMin = -xMax;
else
    xMin = geo.R*cos(pi/geo.p*geo.ps)*1.05;
end

if xMin>0
    xMin = -geo.R*0.05;
end
set(h,'XLim',[xMin xMax]);

% end winding inductance
Lend = calc_Lend(geo);
dataSet.Lend = Lend;

% Rated current computation (thermal model)
dataSet.AdmiJouleLosses = dataSet.ThermalLoadKj*(2*pi*dataSet.StatorOuterRadius*dataSet.StackLength*1e-6);
per.Loss = dataSet.AdmiJouleLosses;
per.tempcuest = temp_est_simpleMod(geo,per);
dataSet.EstimatedCopperTemp = per.tempcuest;
[dataSet.RatedCurrent,dataSet.Rs] = calc_io(geo,per);
dataSet.SimulatedCurrent = dataSet.RatedCurrent * dataSet.CurrLoPP;
per.i0 = dataSet.RatedCurrent;

% Mass and Inertia computation
geo.mCu = calcMassCu(geo,mat);
geo.mPM = calcMassPM(geo,mat);
[geo.mFeS,geo.mFeR] = calcMassFe(geo,mat);
geo.J = calcRotorInertia(geo,mat);

dataSet.MassWinding = geo.mCu;
dataSet.MassMagnet = geo.mPM;
dataSet.MassStatorIron = geo.mFeS;
dataSet.MassRotorIron  = geo.mFeR;
dataSet.RotorInertia   = geo.J;

% Refresh display
dataSet.DepthOfBarrier = round(geo.dx,2);
dataSet.HCpu = round(geo.hc_pu,2);
dataSet.betaPMshape = round(geo.betaPMshape,2);
dataSet.EstimatedCopperTemp = temp_est_simpleMod(geo,per);
dataSet.RotorFillet=geo.RotorFillet;
dataSet.CurrentDensity = per.i0*geo.win.Nbob*2/(geo.Aslot*geo.win.kcu);
dataSet.RotorFillet=geo.RotorFillet;

% dalpha = geo.dalpha;            % barriers ends (deg)
% hc = geo.hc;                    % barriers hieghts (mm)

% set(app.EstimatedCoppTemp,'String',num2str(dataSet.EstimatedCopperTemp));
% set(app.CalculatedRatedCurrent,'String',num2str(dataSet.RatedCurrent));
% set(app.CurrentPP,'String',num2str(dataSet.RatedCurrent));
% set(app.Rsedit,'String',num2str(dataSet.Rs));
if ~strcmp (geo.RotType, 'SPM')
    dataSet.ALPHAdeg = round(100*geo.dalpha)/100;
    dataSet.HCmm = round(100*geo.hc)/100;
%     set(app.AlphadegreeEdit,'String',mat2str(dataSet.ALPHAdeg));
%     set(app.hcmmEdit,'String',mat2str(dataSet.HCmm));
end

dataSet.RadRibEdit = round(geo.pontR*100)/100;
% set(app.RadRibEdit,'String',mat2str(tmp));
dataSet.FilletCorner = geo.SFR;
% set(app.FillCorSlotEdit,'String',mat2str(round(100*geo.SFR)/100));
dataSet.ShaftRadius = floor(geo.Ar*100)/100;

dataSet.PMdim = geo.PMdim;
dataSet.PMclear = geo.PMclear;

app.dataSet = dataSet;



