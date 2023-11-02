%% FUNCTION ws2_fitsReading_comet
%  version/date : version 02, 220926
%  author       : Lorenz Roth - lorenzr@kth.se
%  for KTH course EF2243 - Workshop 2              
%   modified by Arvid Wennerström, Irene Nocerino, Ragnheiður
%   Tryggvadóttir, Thomas Giudicissi

%% DESCRIPTION
%
%  INPUT:   DATADIR         Path
%           OBSERVATION     Name fits-file.
% 
%  OUTPUT:  FITSDATASET     FITS-Image + additional Information
%  (header) about dispersion, central wavelength, etc.
%
clear; clc; close all

% dir_spice = '/Users/arvwe/Documents/SPICE';
dir_spice = 'C:/Users/tomgi/Documents/DD KTH/AA Cours/Solar System/WS1';
% dir_spice = '\Users\dansf\OneDrive\Documents\KTH\Solar System Physics';
% dir_spice = '/Users/irene/Documents/KTH/year 2/Solar System Physics/';

addpath( fullfile(dir_spice, 'mice/') )
addpath( fullfile(dir_spice, 'mice/lib') )
addpath( fullfile(dir_spice, 'mice/doc/html') )
addpath( fullfile(dir_spice, 'mice/src') )
addpath( fullfile(dir_spice, 'mice/src/mice') )
kernels = ["LSK/naif0010.tls","SPK/de440s.bsp","SPK/hst.bsp","SPK/1000109.bsp"];
for kernel_no = 1:length(kernels)
    cspice_furnsh( fullfile(dir_spice, ['kernels/' char(kernels(kernel_no))]))
end

DATADIR     = './HST_Data_46P/';
% OBSERVATIONS_ALL = ["odx605010"];
OBSERVATIONS_ALL = ["odx605010","odx607010","odx628010"]; % root name of files
OBSERVATION_OFFSETS = deg2rad([0,2.5,8]./3600); % [rad] Offset towards the Sun
OBSERVATION_TIMES = ["2019-01-11T09:51","2019-01-11T10:23";"2019-01-11T14:34","2019-01-11T15:06";"2019-01-14T12:32","2019-01-14T13:03"];

for obsNumber = 1:length(OBSERVATIONS_ALL)
    %% main funtion
    OBSERVATION = char(OBSERVATIONS_ALL(obsNumber));

    FITSFILE    = [ OBSERVATION '_flt'];
    FITSDIR     = [ DATADIR FITSFILE '.fits' ] ;
     
     % Read FITS-file:
     
    FITSINFO     = fitsinfo(FITSDIR);   % read header information into structure
        
    FITSDATASET.RAWCOUNTS   = fitsread(FITSDIR,'image',1);  % spectral irradiance per pixel I(x, y) [counts]
    FITSDATASET.ERROR       = fitsread(FITSDIR,'image',2);  % statistical error per pixel sigma(y, x) [counts]
    
    [row,col]       = size(FITSDATASET.RAWCOUNTS); % Number of rows and column / image dimensions
           
    % -- Read specific parameters from header information --
     
    % - EITHER by directly pointing to the sub-indices of the FITSINFO structure

    dateobs = FITSINFO.PrimaryData.Keywords{37,2};  % date start exposure
    timeobs = FITSINFO.PrimaryData.Keywords{38,2};  % time start exposure
    
    % - OR by using the "KeyFinder" routine to search for your keyword by name

    % Read general parameters 
    platesc   = KeyFinder(FITSINFO,'PLATESC'); % plate scale of a detector pixel (arcseconds)
    cenwave  = KeyFinder(FITSINFO,'CENWAVE'); % wavelength (Å) at reference x pixel
    
    % Read parameters specific for image 
    exptime   = KeyFinder(FITSINFO,'EXPTIME','image');  % exposure time (s)
    crpx1    = KeyFinder(FITSINFO,'CRPIX1','image'); % reference x pixel index of target location
    crpx2    = KeyFinder(FITSINFO,'CRPIX2','image'); % reference y pixel index of target location
    cd11     = KeyFinder(FITSINFO,'CD1_1','image');  % dispersion Delta lambda (Å / pixel)
         

    % -- Define image axes 
    xaxis_pix        = ([1:col]) ; % x axis as pixel (spatial) axis
    xaxis_lambda = cenwave+([1:col]-crpx1)*cd11; % x axis as spectral axis
    
    yaxis_pix        = ([1:row]) ; % spatial y axis 
           
    xaxis_arcsec = xaxis_pix/platesc;   % axes as spatial (angular) axes in arcseconds
    yaxis_arcsec = yaxis_pix/platesc;

%% --- Plot raw image ----

    img_plot=FITSDATASET.RAWCOUNTS*1e15; % multiply with 1e15 to be close to 1
    fig_caxis = [0 3];     % Set arbitrary bounds to displayed image
    
    figure();
    
    imagesc(img_plot,fig_caxis); 
      
    set(gca,'ydir','nor') ;  % Define y axis to increase from bottom to top
    axis equal
    xlim([1 col]);
    ylim([1 row]); 
    xlabel('pixel');
    ylabel('pixel'); 
    title(OBSERVATIONS_ALL(obsNumber))

    % display colorbar
    c = colorbar;
    c.Label.String = 'Intensity [counts]';
    c.Label.FontSize = 11;
    clear c
    caxis; % set colormap axis limits
     
    
 %% --- Plot spectrum by summing along slit --- 
    figure();
 
    for jj=1:col
        total_along_the_slit(jj)  = sum(FITSDATASET.RAWCOUNTS(:,jj)) ;
        error_total_along_the_slit(jj)  = sqrt(sum( (FITSDATASET.ERROR(:,jj)).^2 )) ;
    end

    plot(xaxis_lambda,total_along_the_slit); % spectrum (flux vs column)
       
        ylabel('Intensity (counts)')  ;
        ylim([min(total_along_the_slit) max(total_along_the_slit)]);
        xlim([1700 3150]);
        tit=sprintf('Summed counts along the slit');
        title(tit,'Interpreter','none');
        grid on
   
    a1Pos = get(gca,'Position');

    hold on
    plot(xaxis_lambda,error_total_along_the_slit); % propagated error 
    hold off

    %// Place axis 2 below the 1st.
    ax2 = axes('Position',[a1Pos(1) a1Pos(2)-.05 a1Pos(3) a1Pos(4)],'Color','none','YTick',[],'YTickLabel',[]);
    xlim([min(xaxis_pix(:)) max(xaxis_pix(:))])  

    xlabel('Wavelength (Å)  -   Pixel') ;

     %% --
     %-- Helpful factors for unit conversion from [counts] to photon flux
    
        platesc_rad = deg2rad(platesc / 3600);   % pixel platescale in radians
        omega_pix = platesc_rad^2;       % solid angle of one pixels in steradians (rad^2)
    
     %% Q1
     % Offset from comet nucleus towards the Sun, in km
     [dist_HST_comet,dist_offset] = offsetDistance(OBSERVATION_OFFSETS(obsNumber),OBSERVATION_TIMES(obsNumber,:));
     disp(" ")
     disp("Observation " + num2str(obsNumber) + ": " + num2str(3600*rad2deg(OBSERVATION_OFFSETS(obsNumber))) +  "'' equals " + num2str(round(dist_offset,2)) + " km offset " )

    %% Q3
    A_hst = 50^2*pi;
    throughput = 0.02;
    
    [photonThingy, Rayleigh, countsToFlux, fluxToRayleigh] = conversion(A_hst,throughput,omega_pix,exptime,FITSDATASET.RAWCOUNTS);
    
    figure()
    subplot(1,2,1)
    imagesc(photonThingy)
    set(gca,'ydir','nor') ;  % Define y axis to increase from bottom to top
    axis equal
    xlim([1 col]);
    ylim([1 row]); 
    xlabel('pixel');
    ylabel('pixel'); 
    % display colorbar
    c = colorbar;
    c.Label.String = 'Photon flux [photons/cm²/s/sr]';
    c.Label.FontSize = 11;
    clear c
    caxis; % set colormap axis limits

    subplot(1,2,2)
    imagesc(Rayleigh)
    set(gca,'ydir','nor') ;  % Define y axis to increase from bottom to top
    axis equal
    xlim([1 col]);
    ylim([1 row]); 
    xlabel('pixel');
    ylabel('pixel'); 
    % display colorbar
    c = colorbar;
    c.Label.String = 'Rayleigh [R]';
    c.Label.FontSize = 11;
    clear c
    caxis; % set colormap axis limits

    %% Q4 and Q5
    pixel_to_km = dist_HST_comet*tan(platesc_rad);
    disp("One pixel equals " + num2str(round(pixel_to_km,2)) + " km")
    
    slitWidth = 20; % Pixels
    [I_max, brightestPixel] = max(total_along_the_slit);
    Data_focused = FITSDATASET.RAWCOUNTS(:,brightestPixel-round(slitWidth/2):brightestPixel+round(slitWidth/2)-1); 
    Error_focused = FITSDATASET.ERROR(:,brightestPixel-round(slitWidth/2):brightestPixel+round(slitWidth/2)-1); 
    
    [brightness, distAlongSlit] = brightnessOverDistance(Data_focused*countsToFlux,Error_focused*countsToFlux,pixel_to_km,dist_offset,OBSERVATIONS_ALL(obsNumber));


    %% Q6
    NGCD = fluxtocolumndensity(brightness, 315*1e-9);
    
    figure()
    plot(distAlongSlit, NGCD)
    title('OH Column density for ' + OBSERVATIONS_ALL(obsNumber))
    xlim([min(distAlongSlit) max(distAlongSlit)])
    tickLabels = round(sqrt(xticks().^2 + dist_offset^2),-1);
    xticklabels(tickLabels)
    xlabel('Distance from optocenter [km]')
    ylabel('Column density [mol/cm²]')
end

%% -------------------------- Functions -------------------------------
function [dist_HST_comet,dist_offset] = offsetDistance(offsetAngle,timeOfObservation) 
    % INPUT: 
    % offsetAngle = [rad] Offset from nucleus towards Sun
    % timeOfObservation = [string] Time and date of observation
    % OUTPUT:
    % dist_HST_comet = [km] Distance between Hubble and comet
    % dist_offset = [km] Distance of current offset in km

    et_interval = cspice_str2et([char(timeOfObservation(1));char(timeOfObservation(2))]);
    et_step  = 1;
    et_arr = et_interval(1):et_step:et_interval(2);

    [hub_spos, hub_ltime] = cspice_spkpos('-48', et_arr, 'ECLIPJ2000', 'LT', 'SUN');
    [wir_spos, wir_ltime] = cspice_spkpos('1000109', et_arr, 'ECLIPJ2000', 'LT', 'SUN');

    dist_HST_comet = mean(cspice_vdist(hub_spos,wir_spos));
    dist_offset = dist_HST_comet*tan(offsetAngle);
end

function [brightness, distAlongSlit] = brightnessOverDistance(DATA,ERROR,pixel_to_km,dist_offset,obsName)
    % counts = Raw count data 
    % scaling = One pixel equivalent in km
    % offset = Observation offset from optocenter
    
    % centerPixel = height(DATA)/2;
    % counts_folded = [DATA(centerPixel+1:end,:) flip(DATA(1:centerPixel,:))];
    % error_folded = [ERROR(centerPixel+1:end,:) flip(ERROR(1:centerPixel,:))];
    
    N = width(ERROR); % Number of samples, width of slit (20 pixels)
    M = height(ERROR); % Number of measured points along slit (1024 pixels)
    
    brightness = mean(DATA,2);
    error = (1/N)*sqrt(sum(ERROR.^2,2));
    
    [ocenter_value,ocenter_index] = max(brightness);
    distAlongSlit = pixel_to_km*[-ocenter_index+1:M-ocenter_index]; % Linear distance from optocenter along slit
    distProjected = sqrt(distAlongSlit.^2 + dist_offset^2) - dist_offset; % Project absolute distance from ocenter onto slit
    distProjected(1:ocenter_index-1) = -distProjected(1:ocenter_index-1); % Make first half of slit negative, for plotting purposes
    
    % Smooth both graphs
    brightness = smooth(brightness);
    error = smooth(error);

    figure()
    plot(distProjected,brightness)
    hold on
    plot(distProjected,error)
    % plot(distProjected,abs(9.45*1e10./distProjected))
    xlim([min(distProjected) max(distProjected)])
    ylim([min(1.1*brightness) max(1.1*brightness)])
    xticklabels(round(abs(xticks) + dist_offset,-2))
    xlabel('Distance from optocenter [km]')
    ylabel('Photon flux [photons/cm²/s/sr]')
    legend('Brightness','Error')
    title('Brightness for observation ' + obsName)
end

function [photonThingy,Rayleigh,countsToFlux,fluxToRayleigh] = conversion(A_hst, throughput, platescale, exptime, count)
    % A_hst = Area of telescope [cm^2]
    % photonThingy = Photon flux [photons/cm²/s/sr]

    countsToFlux = 1/(exptime*A_hst*throughput*platescale); %[counts] to [photons/cm²/s/sr]
    fluxToRayleigh = 4*pi*1e-6; %[photons/cm²/s/sr] to [R]

    photonThingy = count.*countsToFlux;
    Rayleigh = photonThingy.*fluxToRayleigh;
end
  
function NGCD = fluxtocolumndensity(flux, lambda)
    h =  6.62607015e-34;
    nu = zeros(length(lambda));
    c = 299792458;
    for i=1:length(lambda)
        nu = c/lambda(i);
    end
    L = 4*pi*h*nu*flux;
    alpha0_0 = 2.72e-22; % 1 erg = 1e-7 J, to be adjusted regarding to rdot
    NGCD = L/alpha0_0;

    for i=1:length(NGCD)
        if NGCD(i)<0
            NGCD(i) = 0;
        end
    end
end





