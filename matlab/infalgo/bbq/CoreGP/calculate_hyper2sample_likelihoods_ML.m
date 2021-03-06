function covvy=calculate_hyper2sample_likelihoods_ML(covvy,overwrite,update,next_up,ignore)
% ML_ind here is used purely in case we have a hyper2sample that is giving
% us conditioning issues (even after improve_bmc_conditioning has been
% run). In that event, that hyper2sample is replaced by the ML_ind
% hyper2sample. problematic is the set of hyper2sample indices giving us
% conditioning problems.

%problematic=[];

if nargin<6
    if isfield(covvy,'ignoreHyper2Samples')
        % from zoom_hyper_samples
        ignore = covvy.ignoreHyper2Samples;
    else
        ignore = [];
    end 
end

if nargin<3
% If a hyper2sample was moved at the last time step, we must compute its
% likelihood III and other terms afresh.
if isfield(covvy,'lastHyper2SamplesMoved')
    overwrite = setdiff(covvy.lastHyper2SamplesMoved,ignore);
else
    overwrite = [];
end
end


if nargin<4
% If a hypersample was moved at the last time step, we need to update terms
% to reflect this. Essentially, we need to downdate the relevant row/column
% of the cholesky matrix and then update it.
update = [];
if isfield(covvy,'lastHyperSampleMoved')
    active = covvy.lastHyperSampleMoved;
    if ~isempty(active)
        update = setdiff(1:numel(covvy.hyper2samples),[overwrite,ignore]);
    end
end
end

if nargin<5
% If a hyper2sample is about to be moved, we compute the
% gradient of the log likelihood in order to assist with that
% movement
next_up = setdiff(get_hyper2_samples_to_move(covvy),ignore);
end

active_hp_inds=covvy.active_hp_inds;

hps=active_hp_inds;
Nhyperparams=length(hps);

samples=cat(1,covvy.hypersamples(:).hyperparameters);
Nsamples=size(samples,1);

% Set out the inds that will later be used to transform from the easily
% constructed kron/repmat form to that actually used, which is
% [K(x1,x1),D3K(x1,x1),D2K(x1,x1),D1K(x1,x1),K(x1,x2),D3K(x1,x2),D2K(x1,x2)
% ,D1K(x1,x2),...]
% Note that bsxfun is actually quicker than doing rearrange = ...
% reshape((1:(Nhyperparams+1)*Nsamples),Nsamples,(Nhyperparams+1))'
rearrange=bsxfun(@plus,(0:Nsamples:Nhyperparams*Nsamples)',(1:Nsamples));
rearrange=rearrange(:);

% used later by bmcparams_ahs
covvy.rearrange=rearrange;



for h2sample=union(overwrite,next_up)
    inputscales=exp(covvy.hyper2samples(h2sample).hyper2parameters);
    
    K=ones(size(samples,1));                      
    K_wderivs=ones(size(samples,1)*(Nhyperparams+1));
    DwKcell=mat2cell(ones(Nhyperparams,1),ones(Nhyperparams,1),1);
    
    ind=0;
    for hyperparam=hps;
        ind=ind+1;
        
        width=inputscales(hyperparam);
        samples_hp=samples(:,hyperparam);

        K_hp=matrify(@(x,y) normpdf(x,y,width),...
                                samples_hp,samples_hp);
            
        K=K.*K_hp;
                            
        % NB: the variable you're taking the derivative wrt is negative -
        % so if y>x for DK_hp below, ie. for the upper right corner of the
        % matrix, we expect there to be negatives
        DK_hp=matrify(@(x,y) (x-y)/width^2.*normpdf(x,y,width),...
            samples_hp,samples_hp); 
        DKD_hp=matrify(@(x,y) 1/width^2*(1-((x-y)/width).^2).*normpdf(x,y,width),...
            samples_hp,samples_hp);

        K_wderivs_hp=repmat(K_hp,Nhyperparams+1,Nhyperparams+1);
        inds=(Nhyperparams+1-ind)*Nsamples+(1:Nsamples); % derivatives are still listed in reverse order for a bit of consistency
        K_wderivs_hp(inds,:)=repmat(-DK_hp,1,Nhyperparams+1);
        K_wderivs_hp(:,inds)=K_wderivs_hp(inds,:)';
        K_wderivs_hp(inds,inds)=DKD_hp;

        K_wderivs=K_wderivs.*K_wderivs_hp;
        
        if ismember(h2sample,next_up)
            
            % DwKcell=d/d(log_hyperscales) K(samples inc. deriv obs,samples inc. deriv obs)
            % each cell of DwKcell is the deriv wrt a different log_hyperscale
            
            % The derivs wrt w_hyperparam have no effect on these sheets
            DwKcell([1:ind-1,ind+1:Nhyperparams])=...
                cellfun(@(DwKmat) DwKmat.*K_wderivs_hp,...
                DwKcell([1:ind-1,ind+1:Nhyperparams]),...
                'UniformOutput', false);
            
            % This is the derivative of K=normpdf(x,y,width) wrt log(width)
            DwK_hp=matrify(@(x,y) (((x-y)/width).^2-1).*normpdf(x,y,width),...
                samples_hp,samples_hp);
            
            % NB: the variable you're taking the derivative wrt is negative
            DwDK_hp=matrify(@(x,y) (x-y)/width^2.*(((x-y)/width).^2-3).*normpdf(x,y,width),...
                samples_hp,samples_hp); 
            DwDKD_hp=matrify(@(x,y) 1/width^6.*(-3*width^4+6*width^2*(x-y).^2-(x-y).^4).*normpdf(x,y,width),...
                samples_hp,samples_hp);

            DwKmat_hp=repmat(DwK_hp,Nhyperparams+1,Nhyperparams+1);
            DwKmat_hp(inds,:)=repmat(-DwDK_hp,1,Nhyperparams+1); 
            DwKmat_hp(:,inds)=DwKmat_hp(inds,:)';
            DwKmat_hp(inds,inds)=DwDKD_hp;            
            
            DwKcell(ind)=...
                cellfun(@(DwKmat) DwKmat.*DwKmat_hp,...
                DwKcell(ind),...
                'UniformOutput', false);
            

        end 
    end
    
    % HAVE K FLOATING AROUND UP THERE IF WE WANT IT - nah stuff it, will
    % recompute it in bmcparams_ahs
    
    
    % really there should be only one chol call below and two
    % updatechol/downdatechol calls, but having the candidates all mixed in
    % makes it more tricky than seems worthwhile.
    
    if ~ismember(h2sample,update)
        % used for computing likelihood III
%         try
            cholK=chol(K);
            covvy.hyper2samples(h2sample).cholK=cholK;
        
            K_wderivs=K_wderivs(rearrange,rearrange);
            cholK_wderivs = chol(K_wderivs);
            covvy.hyper2samples(h2sample).cholK_wderivs = cholK_wderivs;
%         catch
%             problematic=[problematic,h2sample];
%         end
        
    end
    
    if ismember(h2sample,next_up)
        DwKcell=cellfun(@(DwKmat) DwKmat(rearrange,rearrange),...
                    DwKcell,'UniformOutput', false);
        covvy.hyper2samples(h2sample).DwKcell=DwKcell;
    end

    

    

end



for h2sample = update
    inputscales=exp(covvy.hyper2samples(h2sample).hyper2parameters);
    
    cholK=covvy.hyper2samples(h2sample).cholK; 
    cholK = downdatechol(cholK,active);
    
    
    cholK_wderivs=covvy.hyper2samples(h2sample).cholK_wderivs; 
    active_inds=(active-1)*(Nhyperparams+1)+(1:Nhyperparams+1);
    try
        cholK_wderivs = downdatechol(cholK_wderivs,active_inds);
    catch
        keyboard
    end
    
    K_wderivs=ones(size(samples,1)*(Nhyperparams+1));
    
    ind=0;
    for hyperparam=hps;
        ind=ind+1;
        
        width=inputscales(hyperparam);
        samples_hp=samples(:,hyperparam);
        activesamples_hp=samples(active,hyperparam);

        K_hp=nan(Nsamples);
        K_hp(active,:) =...
                    matrify(@(x,y) normpdf(x,y,width),...
                                    activesamples_hp,samples_hp);
        K_hp(:,active) = K_hp(active,:)';
                            
        % NB: the variable you're taking the derivative wrt is negative
        DK_hp=nan(Nsamples);
        DK_hp(active,:)=matrify(@(x,y) (x-y)/width^2.*normpdf(x,y,width),...
            activesamples_hp,samples_hp); 
        DK_hp(:,active) = DK_hp(active,:)';
        
        DKD_hp=nan(Nsamples);
        DKD_hp(active,:)=matrify(@(x,y) 1/width^2*(1-((x-y)/width).^2).*normpdf(x,y,width),...
            activesamples_hp,samples_hp);
        DKD_hp(:,active) = DKD_hp(active,:)';

        K_wderivs_hp=repmat(K_hp,Nhyperparams+1,Nhyperparams+1);
        inds=(Nhyperparams+1-ind)*Nsamples+(1:Nsamples);
        K_wderivs_hp(inds,:)=repmat(-DK_hp,1,Nhyperparams+1);
        K_wderivs_hp(:,inds)=K_wderivs_hp(inds,:)';
        K_wderivs_hp(inds,inds)=DKD_hp;

        K_wderivs=K_wderivs.*K_wderivs_hp;
    end
    
    
            cholK=updatechol(K_hp,cholK,active);
            covvy.hyper2samples(h2sample).cholK=cholK;
        
    
    K_wderivs=K_wderivs(rearrange,rearrange);
    
%   try
        cholK_wderivs = updatechol(K_wderivs,cholK_wderivs,active_inds);
        covvy.hyper2samples(h2sample).cholK_wderivs = cholK_wderivs;
%      catch
%          problematic=[problematic,h2sample];
%      end
    
end

lowr.UT=true;
lowr.TRANSA=true;
uppr.UT=true;

% Note that the likelihoods used have been multiplied by a positive
% constant so that largest likelihood observed is always one. This is done
% for numerical reasons, so that exp(logL) is non-zero for at least one
% value (not always the case otherwise!). Note that we're only ever
% interested in relative ratios of likelihoods, so this has no impact on
% our inference.

[logLcell{1:Nsamples}]=covvy.hypersamples(:).logL;
logLvec=cat(1,logLcell{:});
[max_logLvec,max_logL_ind]=max(logLvec);
logLvec=(logLvec-max_logLvec); 
Lvec=exp(logLvec);%,eps);

%h_L=sqrt(mean(Lvec.^2));


[glogLcell{1:Nsamples}]=covvy.hypersamples(:).glogL; % actually glogl is a cell itself
glogLmat=fliplr(cell2mat(cat(2,glogLcell{:}))');
glogLmat=glogLmat(:,end+1-active_hp_inds);
gLmat=fliplr(repmat(Lvec,1,size(glogLmat,2))).*glogLmat; %fliplr because derivs are actually in reverse order

% recall that observations are ordered as [L_1,gL_1,L_2,gL_2,...]

LData=[Lvec,gLmat]';
LData=LData(:);

% Subtract the min so that the mean of the GP over tilda likelihood space
% is equal to the min of logLvec
mean_tildal=min(min(logLvec),-2);
covvy.mean_tildal=mean_tildal;

logLvec2=logLvec-mean_tildal;
tilda_LData=[logLvec2,glogLmat]'; 
tilda_LData=tilda_LData(:);

NLData = size(LData, 1);

% problematic
% not_problematic=setdiff(union(overwrite,update),problematic);

if ~isfield(covvy,'SD_factor_tildaL');
    covvy.SD_factor_tildaL=0.1;
end
SD_factor_tildaL=covvy.SD_factor_tildaL;

if ~isfield(covvy,'SD_factor_L');
    covvy.SD_factor_L=10;
end
SD_factor_L=covvy.SD_factor_L;


for h2sample=union(union(overwrite,update),next_up)
    
    inputscales=exp(covvy.hyper2samples(h2sample).hyper2parameters);
    norm2SE_factor=sqrt(sqrt(prod(2*pi*inputscales(active_hp_inds).^2)));
    
    cholK=covvy.hyper2samples(h2sample).cholK;
   
    
    % We always overwrite logL as it is assumed that the
    % likelihood-II surface (if not the points at which we have
    % observations of it) is changing every time step
    
    cholK_wderivs=covvy.hyper2samples(h2sample).cholK_wderivs;
   
    datahalf = linsolve(cholK_wderivs, LData, lowr); % Mean assumed as zero
    covvy.hyper2samples(h2sample).datahalf=datahalf; 
    quad = (datahalf'*datahalf);
    
    % the ML solution for h_L can be computed analytically:
    SD=SD_factor_L*sqrt(quad/NLData);
    b=(0.5*NLData*SD^2);
    h_L = sqrt(-b+sqrt(b^2+SD^2*quad)); %*norm2SE_factor^(-1) - include this factor if you want h_L for a SE covariance rather than a normal covariance
    covvy.hyper2samples(h2sample).likelihood_scale=h_L;

    % used by sample_candidate_likelihoods, but only for the ML
    % hyper2sample.
    datatwothirds = linsolve(cholK_wderivs, datahalf, uppr);
    covvy.hyper2samples(h2sample).datatwothirds=datatwothirds; 

    % Maybe better stability elsewhere would result from sticking in this
    % output scale earlier?
    scaled_cholK_wderivs=h_L*cholK_wderivs; %*norm2SE_factor
    scaled_datahalf=(h_L)^(-1)*datahalf; %norm2SE_factor^(-1)
    scaled_datatwothirds=(h_L)^(-2)*datatwothirds; %norm2SE_factor^(-2)
    
    logsqrtInvDetSigma = -sum(log(diag(scaled_cholK_wderivs)));
    quadform = sum(scaled_datahalf.^2, 1); %=NLData
    logL = -0.5 * NLData * log(2 * pi) + logsqrtInvDetSigma -0.5 * quadform;
    covvy.hyper2samples(h2sample).logL=logL; 
    
    % Given we can only move a hyper2sample once, we arbitrarily choose to
    % move it according to the gradient computed on the likelihood, as
    % opposed to the tilda likelihood
    if ismember(h2sample,next_up) % h2sample==next_up <- this is MUCH faster
        
        DwKcell=covvy.hyper2samples(h2sample).DwKcell;
        %Kinvt = (eye(NLData) / cholK_wderivs) / cholK_wderivs';
        glogL = cellfun(@(DwKmat) - 0.5 * trace(solve_chol(scaled_cholK_wderivs,h_L^2*DwKmat))...%Kinvt(:)' * h_L^2*DwKmat(:) ...
                                         + 0.5 * scaled_datatwothirds' * h_L^2*DwKmat * scaled_datatwothirds, DwKcell, ...
                                        'UniformOutput', false); % similarly, h_L's in this eqn are actually h_L*norm2SE_factor

        % Note the ratio of the two terms in glogL is controlled by
        % h_tildaL - it is significant!
                                    
        covvy.hyper2samples(h2sample).glogL = glogL; 
    end
    
    
    % now do the same for tilda likelihoods
    
    tilda_datahalf = linsolve(cholK_wderivs, tilda_LData, lowr); % Mean assumed as zero
    covvy.hyper2samples(h2sample).tilda_datahalf=tilda_datahalf; 
    quad = (tilda_datahalf'*tilda_datahalf);
    
    % the ML solution for h_L can be computed analytically:
    SD=SD_factor_tildaL*sqrt(quad/NLData);
    b=(0.5*NLData*SD^2);
    h_tildaL = sqrt(-b+sqrt(b^2+SD^2*quad)); %*norm2SE_factor^(-1) - include this factor if you want h_L for a SE covariance rather than a normal covariance
    covvy.hyper2samples(h2sample).tilda_likelihood_scale=h_tildaL;

    % used by sample_candidate_likelihoods, but only for the ML
    % hyper2sample.
    tilda_datatwothirds = linsolve(cholK_wderivs, tilda_datahalf, uppr);
    covvy.hyper2samples(h2sample).tilda_datatwothirds=tilda_datatwothirds; 

    % Maybe better stability elsewhere would result from sticking in this
    % output scale earlier?
    tilda_scaled_cholK_wderivs=h_tildaL*cholK_wderivs; %*norm2SE_factor
    tilda_scaled_datahalf=(h_tildaL)^(-1)*tilda_datahalf; %norm2SE_factor^(-1)
    %tilda_scaled_datatwothirds=(h_tildaL)^(-2)*tilda_datatwothirds; %norm2SE_factor^(-2)
    
    logsqrtInvDetSigma = -sum(log(diag(tilda_scaled_cholK_wderivs)));
    quadform = sum(tilda_scaled_datahalf.^2, 1); %=NLData
    tilda_logL = -0.5 * NLData * log(2 * pi) + logsqrtInvDetSigma -0.5 * quadform;
    covvy.hyper2samples(h2sample).tilda_logL=tilda_logL; 
    

    
end

% for h2sample=problematic
%     covvy.hyper2samples(h2sample).logL=[];
% end

for h2sample=ignore
    covvy.hyper2samples(h2sample).logL = nan;
    covvy.hyper2samples(h2sample).tilda_logL = nan;
    covvy.hyper2samples(h2sample).Q_logL = nan;
    covvy.hyper2samples(h2sample).tildaQ_logL = nan;
    covvy.hyper2samples(h2sample).glogL = mat2cell(zeros(Nhyperparams,1),ones(Nhyperparams,1),1); 
end
covvy.ignoreHyper2Samples=[];

[ML,ML_ind] = max([covvy.hyper2samples(:).logL]);
%ML_ind
covvy.ML_hyper2sample_ind=ML_ind;

[ML_tilda,ML_tilda_ind] = max([covvy.hyper2samples(:).tilda_logL]);
%ML_tilda_ind
covvy.ML_tilda_hyper2sample_ind=ML_tilda_ind;

covvy.lastHyper2SamplesMoved=[]; % All dealt with
covvy.lastHyperSampleMoved=[];

% not_problematic=setdiff(1:numel(covvy.hyper2samples),problematic);
% 
% if ~isempty(problematic)
%     
%     hyper2samples=cat(1,covvy.hyper2samples(not_problematic).hyper2parameters);
%     scales=[covvy.samplesSD{:}];
%     bounds=[min(hyper2samples)-scales;max(hyper2samples)+scales];
%     explore_points = find_farthest(hyper2samples,bounds, length(problematic), scales);
%     num_explore_points=size(explore_points,1);
%     i=0;
%     for h2sample=problematic
%         i=i+1;
%         if i<=num_explore_points
%             covvy.hyper2samples(h2sample).hyper2parameters=explore_points(i,:);
%         else
%             % if we run out of explore points, just use the ML sample
%             covvy.hyper2samples(h2sample)=covvy.hyper2samples(ML_ind);
%         end
%     end
%     covvy=calculate_hyper2sample_likelihoods(covvy,problematic(1:num_explore_points),[]);
% end
    