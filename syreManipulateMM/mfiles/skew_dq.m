% Copyright 2020
%
%    Licensed under the Apache License, Version 2.0 (the "License");
%    you may not use this file except in compliance with the License.
%    You may obtain a copy of the License at
%
%        http://www.apache.org/licenses/LICENSE-2.0
%
%    Unless required by applicable law or agreed to in writing, software
%    distributed under the License is distributed on an "AS IS" BASIS,
%    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%    See the License for the specific language governing permissions and
%    limitations under the License.

function [fdfq,ironLoss] = skew_dq(motorModel)

% Load data
axisType  = motorModel.data.axisType;
motorType = motorModel.data.motorType;
p         = motorModel.data.p;
Lld       = motorModel.data.Lld;
Llq       = motorModel.data.Llq;


fdfq     = motorModel.fdfq;
ironLoss = motorModel.ironLoss;

% new current limits
ang_sk_m = motorModel.skew.thSkw;
nSlice   = motorModel.skew.nSlice;
nPoints  = motorModel.skew.nPoints;

ang_sk = ang_sk_m*p*pi/180; % elt rad
k = 1:1:nSlice;
k = k-mean(k);
alfa_k = k*ang_sk/(nSlice);
rot_alfa_k = exp(-1i*alfa_k);

IdMax = max(fdfq.Id,[],'all');
IdMin = min(fdfq.Id,[],'all');
IqMax = max(fdfq.Iq,[],'all');
IqMin = min(fdfq.Iq,[],'all');

% max current amplitude (diagonal of the id iq rectangle)
% diagonal_raw = abs(IdMax + 1j*IqMax);
diagonal_angle = angle(IdMax + 1j*IqMax);
% reduced diagonal (tentative)
diagonal_temp = IdMax/(cos(diagonal_angle-ang_sk/2));
id_span_new = diagonal_temp * cos(diagonal_angle);
iq_span_new = diagonal_temp * sin(diagonal_angle);
% if no good, try the other side
if (iq_span_new > IqMax)
    diagonal_temp = IqMax/(cos(diagonal_angle-ang_sk/2));
    id_span_new = diagonal_temp * cos(diagonal_angle);
    iq_span_new = diagonal_temp * sin(diagonal_angle);
end

% 2D matrixes of skewed machine
if IdMin==-IdMax
    id = linspace(-id_span_new,id_span_new,nPoints);
else
    id = linspace(IdMin,id_span_new,nPoints);
end
if IqMin==-IqMax
    iq = linspace(-iq_span_new,iq_span_new,nPoints);
else
    iq = linspace(IqMin,iq_span_new,nPoints);
end

[Id,Iq] = meshgrid(id,iq);

% interpolant and new matrices
fInt.Fd = griddedInterpolant(fdfq.Id',fdfq.Iq',fdfq.Fd'-Lld*fdfq.Id','linear','none');
fInt.Fq = griddedInterpolant(fdfq.Id',fdfq.Iq',fdfq.Fq'-Llq*fdfq.Id','linear','none');
fInt.T  = griddedInterpolant(fdfq.Id',fdfq.Iq',fdfq.T','linear','none');

Fd = zeros(size(Id));
Fq = zeros(size(Iq));
T  = zeros(size(Id));

if ~isempty(ironLoss)
    fInt.Pfes_h = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Pfes_h','linear','none');
    fInt.Pfes_c = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Pfes_c','linear','none');
    fInt.Pfer_h = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Pfer_h','linear','none');
    fInt.Pfer_c = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Pfer_c','linear','none');
    fInt.Ppm    = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Ppm','linear','none');
    %fInt.Pfe    = griddedInterpolant(ironLoss.Id',ironLoss.Iq',ironLoss.Pfe','linear','none');
    
    Pfes_c = zeros(size(Id));
    Pfes_h = zeros(size(Id));
    Pfer_c = zeros(size(Id));
    Pfer_h = zeros(size(Id));
    Ppm    = zeros(size(Id));
%     Pfe    = zeros(size(Id));
    
    %velDim = ironLoss.n0;
end

for ss=1:length(alfa_k)
    Idq = (Id+j*Iq)*rot_alfa_k(ss);
    FdSlice = fInt.Fd(real(Idq),imag(Idq));
    FqSlice = fInt.Fq(real(Idq),imag(Idq));
    IdSlice = real(Idq);
    IqSlice = imag(Idq);
    TSlice  = fInt.T(real(Idq),imag(Idq));
    if ~isempty(ironLoss)
        Pfes_cSlice = fInt.Pfes_c(real(Idq),imag(Idq));
        Pfes_hSlice = fInt.Pfes_h(real(Idq),imag(Idq));
        Pfer_cSlice = fInt.Pfer_c(real(Idq),imag(Idq));
        Pfer_hSlice = fInt.Pfer_h(real(Idq),imag(Idq));
        PpmSlice    = fInt.Ppm(real(Idq),imag(Idq));
        %PfeSlice    = fInt.Pfe(real(Idq),imag(Idq));
    end
    
    if strcmp(motorType,'SR')
        % symmetry on both axis
        if (abs(IdMin)<IdMax)
            FdSlice(real(Idq)<0) = -fInt.Fd(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
            FqSlice(real(Idq)<0) = +fInt.Fq(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
            TSlice(real(Idq)<0) = -fInt.T(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
            if ~isempty(ironLoss)
                Pfes_cSlice(real(Idq)<0) = fInt.Pfes_c(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                Pfes_hSlice(real(Idq)<0) = fInt.Pfes_h(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                Pfer_cSlice(real(Idq)<0) = fInt.Pfer_c(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                Pfer_hSlice(real(Idq)<0) = fInt.Pfer_h(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                PpmSlice(real(Idq)<0)    = fInt.Ppm(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                %PfeSlice(real(Idq)<0)    = fInt.Pfe(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
            end
        end
        if (abs(IqMin)<IqMax)
            FdSlice(imag(Idq)<0) = +fInt.Fd(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
            FqSlice(imag(Idq)<0) = -fInt.Fq(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
            TSlice(imag(Idq)<0) = -fInt.T(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
            if ~isempty(ironLoss)
                Pfes_cSlice(imag(Idq)<0) = fInt.Pfes_c(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                Pfes_hSlice(imag(Idq)<0) = fInt.Pfes_h(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                Pfer_cSlice(imag(Idq)<0) = fInt.Pfer_c(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                Pfer_hSlice(imag(Idq)<0) = fInt.Pfer_h(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                PpmSlice(imag(Idq)<0)    = fInt.Ppm(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                %PfeSlice(imag(Idq)<0)    = fInt.Pfe(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
            end
        end
    elseif strcmp(motorType,'PM')
        if strcmp(axisType,'SR')
            %symmetry just on d axis
            if (abs(IdMin)<IdMax)
                FdSlice(real(Idq)<0) = -fInt.Fd(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
                FqSlice(real(Idq)<0) = +fInt.Fq(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
                TSlice(real(Idq)<0) = -fInt.T(-IdSlice(real(Idq)<0),IqSlice(real(Idq)<0));
                if ~isempty(ironLoss)
                    Pfes_cSlice(real(Idq)<0) = fInt.Pfes_c(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                    Pfes_hSlice(real(Idq)<0) = fInt.Pfes_h(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                    Pfer_cSlice(real(Idq)<0) = fInt.Pfer_c(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                    Pfer_hSlice(real(Idq)<0) = fInt.Pfer_h(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                    PpmSlice(real(Idq)<0)    = fInt.Ppm(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                    %PfeSlice(real(Idq)<0)    = fInt.Pfe(real(Idq(real(Idq)<0)),imag(Idq(real(Idq)<0)));
                end
            end
            if (abs(IqMin)<IqMax)
                FdSlice(imag(Idq)<0) = NaN;
                FqSlice(imag(Idq)<0) = NaN;
                TSlice(imag(Idq)<0) = NaN;
                if ~isempty(ironLoss)
                    Pfes_cSlice(imag(Idq)<0) = NaN;
                    Pfes_hSlice(imag(Idq)<0) = NaN;
                    Pfer_cSlice(imag(Idq)<0) = NaN;
                    Pfer_hSlice(imag(Idq)<0) = NaN;
                    PpmSlice(imag(Idq)<0)    = NaN;
                    %PfeSlice(imag(Idq)<0)    = NaN;
                end
            end
        else
            % symmetry just on q axis
            if (IdMax<abs(IdMin))
                FdSlice(real(Idq)>0) = NaN;
                FqSlice(real(Idq)>0) = NaN;
                TSlice(real(Idq)>0) = NaN;
                if ~isempty(ironLoss)
                    Pfes_cSlice(real(Idq)<0) = NaN;
                    Pfes_hSlice(real(Idq)<0) = NaN;
                    Pfer_cSlice(real(Idq)<0) = NaN;
                    Pfer_hSlice(real(Idq)<0) = NaN;
                    PpmSlice(real(Idq)<0)    = NaN;
                    %PfeSlice(real(Idq)<0)    = NaN;
                end
            end
            if (abs(IqMin)<IqMax)
                FdSlice(imag(Idq)<0) = +fInt.Fd(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
                FqSlice(imag(Idq)<0) = -fInt.Fq(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
                TSlice(imag(Idq)<0) = -fInt.T(IdSlice(imag(Idq)<0),-IqSlice(imag(Idq)<0));
                if ~isempty(ironLoss)
                    Pfes_cSlice(imag(Idq)<0) = fInt.Pfes_c(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                    Pfes_hSlice(imag(Idq)<0) = fInt.Pfes_h(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                    Pfer_cSlice(imag(Idq)<0) = fInt.Pfer_c(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                    Pfer_hSlice(imag(Idq)<0) = fInt.Pfer_h(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                    PpmSlice(imag(Idq)<0)    = fInt.Ppm(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                    %PfeSlice(imag(Idq)<0)    = fInt.Pfe(real(Idq(imag(Idq)<0)),imag(Idq(imag(Idq)<0)));
                end
            end
        end
    end
    
    Fd = Fd+FdSlice/length(alfa_k);
    Fq = Fq+FqSlice/length(alfa_k);
    T = T+TSlice/length(alfa_k);
    
    if ~isempty(ironLoss)
        Pfes_c = Pfes_c+Pfes_cSlice/length(alfa_k);
        Pfes_h = Pfes_h+Pfes_hSlice/length(alfa_k);
        Pfer_c = Pfer_c+Pfer_cSlice/length(alfa_k);
        Pfer_h = Pfer_h+Pfer_hSlice/length(alfa_k);
        Ppm    = Ppm+PpmSlice/length(alfa_k);
        %Pfe    = Pfe+PfeSlice/length(alfa_k);
    end
end

Fd = Fd+Lld*Id;
Fq = Fq+Llq*Iq;

fdfq.Id = Id;
fdfq.Iq = Iq;
fdfq.Fd = Fd;
fdfq.Fq = Fq;
fdfq.T  = T;

if ~isempty(ironLoss)
    ironLoss.Id = Id;
    ironLoss.Iq = Iq;
    ironLoss.Pfes_h = Pfes_h;
    ironLoss.Pfes_c = Pfes_c;
    ironLoss.Pfer_h = Pfer_h;
    ironLoss.Pfer_c = Pfer_c;
    ironLoss.Ppm    = Ppm;
    ironLoss.Pfe    = Pfes_h+Pfes_c+Pfer_h+Pfer_c;
end







