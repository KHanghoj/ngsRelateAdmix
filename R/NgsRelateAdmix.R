library(SQUAREM)

norma<- function(x){
  xNorm<-c()
  for (i in 1:length(x)){
    xNorm[i]<-x[i]/sum(x)
  }
  return(xNorm)
}

simGeno<-function(k1,k2,a1,a2,f){
  K<-ncol(f) #No. of populations
  M<-nrow(f)
  # ancestral allele frequency weighted using the ancestry proportions for each individual.
  #F1<-f%*%norma(a1-k2-k1/2) #Individ 1 population allele frequencies. norma er en hjemmelavet function der normalicere vektore, så de summer til 1. (0.5 0.0 0.0) becomes (1.0 0.0 0.0)
  #F2<-f%*%norma(a2-k2-k1/2) #Individ 2 population allele frequencies
  F1<-f%*%norma(a1) #Individ 1 population allele frequencies. norma er en hjemmelavet function der normalicere vektore, så de summer til 1. (0.5 0.0 0.0) becomes (1.0 0.0 0.0)
  F2<-f%*%norma(a2) #Individ 2 population allele frequencies
  
  ###two unrelated individuals haplotypes (the parents)
  #sampling the genotypes independently per site
  hap11<-rbinom(M,1,F1) #gelerate vector of length N with random values of 0 and 1. Estimate for individual 1 at each loci of allele 1 if the allele is 0 or 1 based on the 3 probabilities. E.g if f1[1,]=(0.04087375 0.2330954 0.03205951) it is most likely that the outcome is 0. However in some cases even though it is more likely that the outcom is 0 will the outcome be 1.  
  hap12<-rbinom(M,1,F1)
  hap21<-rbinom(M,1,F2)
  hap22<-rbinom(M,1,F2)
  
  ####samples state (0 is unrelated)
  states<-sample(0:(2*K),M,replace=T,prob=c(1-sum(k1)-sum(k2),k1,k2)) # generates a vector of length N containing a weighed random distribution with the values 0, 1, 2, 3, 4, 5, 6, with probability 0.25 0.50    0.00 0.00 0.25 0.00 0.00. z0 (IBD=0) er kun repræsenteret med et tal: 1-sum(z1)-sum(z2) = 0.25. 
  #table(states)
  #    0     1     4 
  #24877 50274 24849
  ###two siblings were simulated by randomly sampling alleles from the two parents.
  for(p in 1:K){
    #ibd=1
    s1<-rbinom(M,1,f[,p]) #for hver population generate a vector of length N containing 0 and 1 based on the probability of f[,p]. 
    hap11[states==p] <-s1[states==p] # if states == 1,   
    hap21[states==p] <-s1[states==p]
    ##ibd=2
    s21<-rbinom(M,1,f[,p])
    s22<-rbinom(M,1,f[,p])
    hap11[states==p+K] <-s21[states==p+K]
    hap21[states==p+K] <-s21[states==p+K]
    hap12[states==p+K] <-s22[states==p+K]
    hap22[states==p+K] <-s22[states==p+K]
    #    print(mean(states==p))
  }
  
  return(cbind(hap11+hap12,hap21+hap22)) #return(cbind(hap11,hap12,hap21,hap22))
}

###Genotype likelihoods
## x er vector med 0,1,2
getLikes<-function(x,d=5,e=0.01,norm=FALSE){
  n<-length(x)
  dep<-rpois(n,d) # depth follows a poisson distribution with mean d and length n.
  #dep bases are sampled at each site based on the individual's genotype
  nA<-rbinom(n,dep,c(e,0.5,1-e)[x+1]) # generate the number of a at each site . and probability c(e,0.5,1-e)[x+1]=probability taht the base is a fx. x=2 1 0 1 1 2 , where 2=aa, 1=Aa, and 0=AA-> 0.99 0.50 0.01 0.50 0.50 0.99 
  res<-rbind(dbinom(nA,dep,e),dbinom(nA,dep,0.5),dbinom(nA,dep,1-e))# P(X|G=AA),P(X|G=Aa),P(X|G=aa)
  #res= genotype likelihood, række 1 er GL for AA, række 2, GL for Aa, række 3 GL for aa 
  if(norm)
    res<-t(t(res)/colSums(res))
  res
}

### Maximum likelihood
NgsAdmixRelateML<-function(Z,a1,a2,f,GL1, GL2,n=1,pprint=TRUE){ 
  
  ssum<-0
  count<-0
  npop<-length(a1)
  for(a11 in 1:npop){
    if(a1[a11]==0)
      next
    for(a12 in 1:npop){ #ind 1 haplo 2
      if(a1[a12]==0) # if aij==0 skip this iteration (next), since the unobserved ancestral population is 0
        next
      for(a21 in 1:npop){
        if(a2[a21]==0)
          next
        for(a22 in 1:npop){
          if(a2[a22]==0)
            next
          for(z1 in 0:1){ #hap1
            if(z1==1&a11!=a21) #skip iterations where k1 (indicates whether allele 1 is IBD) is 1 and a11!=a21 since alleles can not be IBD if they are from different popu.
              next
            for(z2 in 0:1){ #hap2
              if(z2==1&a12!=a22)
                next
              for(g11 in 0:1){
                for(g12 in 0:1){
                  for(g21 in 0:1){
                    for(g22 in 0:1){
                
                      count<-count+1
                        
                      #######################################
                      ## probability of IBD given relatedness (P(Z=z|R))
                      ########################################
                      Pr<-Z[z1+z2+1]/2^(z1!=z2)
                        
                      ########################################
                      ## probablity of ancestral proportions given IBD and Ancestry proportions (P(Aj=a|Zj=z, Q1, Q2))
                      ########################################
                        
                      #if(k1==0 & k2 ==0)
                      Pa<-a1[a11]*a1[a12]*a2[a21]*a2[a22] #tab2
                      
                      if(z1==1)
                        Pa<-Pa/(sum(a1*a2))
                      if(z2==1)
                        Pa<-Pa/(sum(a1*a2))
                        
    
                        
                      ########################################
                      ###probability of data given genotype (P(X|Gj=g1,g2))
                      ########################################
                      if(g11+g12==1){
                        PGL1<-GL1[g11+g12+1,]/2
                      }
                      else{
                        PGL1<-GL1[g11+g12+1,]
                      }
                      
                      if(g21+g22==1){
                        PGL2<-GL2[g21+g22+1,]/2
                      }
                      else{
                        PGL2<-GL2[g21+g22+1,]
                      }
                        
                      ########################################
                      ###probability of genotypes given relatedness (P(G1j=g1, G2j=g2|Aj=a, Zj=z))
                      ########################################
                      ## probablity of data
                      
                      if(Pr==0)
                        next
                        
          
                      if(z1==1)
                        P1<-ifelse(g11==g21,g21+(-1)^g21*f[,a11],0) 
                     
                      else     #ind1 hap1                    #ind2 hap1
                        P1<-(g11+(-1)^g11*f[,a11]) * (g21+(-1)^g21*f[,a21])
                       
                        
                      if(z2==1)
                        P2<-ifelse(g12==g22,g22+(-1)^g22*f[,a22],0)
                       
                      else     #ind1 hap2                    #ind2 hap2
                        P2<-(g12+(-1)^g12*f[,a12]) * (g22+(-1)^g22*f[,a22])
                        
                      mult<-1
                      mult <- ifelse(g11!=g12 ,mult *2 ,mult)
                      mult <- ifelse(g21!=g22 ,mult *2 ,mult)
                      
                      if(z1+z2 > 0)
                        mult <- ifelse(g11!=g12 & g21!=g22,mult/2 ,mult)
                        
                        
                      ppart<-Pa*Pr*P1*P2*mult*PGL1*PGL2
                      ssum<-ssum+ppart
                    
                      if(pprint)

                      cat(count,"a:",a11,a12,a21,a22,"Z:",z1,z2,"G1:",g1,g2,"Pa=",Pa,"Pr=",Pr,"PGL1=",PGL1[n],"PGL2=",PGL2[n],"sum=",ssum[n],"ppart=",ppart[n],"P1*P2=",P1[n]*P2[n]*mult[n],"mult",mult[n],"\n")
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  logL<--sum(log(ssum))
  return(logL)
}

################################################################
#####Old version which calculate all probabilities in each loop of a EM step
################################################################
NgsAdmixRelateEMoneStepOld<-function(par,a1,a2,f,GL1, GL2,n=1,pprint=TRUE){
  Z<-par
  ssum<-0
  count<-0
  site<-0
  npop<-length(a1)
  Ek <- matrix(0,ncol=4,nrow=length(f[,1]))
  
  for(a11 in 1:npop){
    if(a1[a11]==0)
      next
    for(a12 in 1:npop){ 
      if(a1[a12]==0)
        next
      for(a21 in 1:npop){
        if(a2[a21]==0)
          next
        for(a22 in 1:npop){
          if(a2[a22]==0)
            next
          for(z1 in 0:1){ 
            if(z1==1&a11!=a21)
              next
            for(z2 in 0:1){ 
              if(z2==1&a12!=a22)
                next
              for(g11 in 0:1){
                for(g12 in 0:1){
                  for(g21 in 0:1){
                    if(z1==1&g11!=g21)
                      next
                    for(g22 in 0:1){
                      if(z2==1&g12!=g22)
                        next
                      
                  
                    count<-count+1
                    
                    #######################################
                    ## probability of IBD given relatedness (P(Z=z|R))
                    ########################################
                    Pz<-Z[z1+z2+1]/2^(z1!=z2)
                    
                    if(Pz==0)
                      next
                    
                    ########################################
                    ## probablity of ancestral proportions given IBD and Ancestry proportions (P(Aj=a|Zj=z, Q1, Q2)) tabel 2
                    ########################################
                    Pa<-a1[a11]*a1[a12]*a2[a21]*a2[a22]
                    
                    if(z1==1)
                      Pa<-Pa/(sum(a1*a2))
                    if(z2==1)
                      Pa<-Pa/(sum(a1*a2))
                    
                    ########################################
                    ###probability of data given genotype (P(X|Gj=g1,g2))
                    ########################################
                    if(g11+g12==1){
                      PGL1<-GL1[g11+g12+1,]/2
                    }
                    else{
                      PGL1<-GL1[g11+g12+1,]
                    }
                    
                    if(g21+g22==1){
                      PGL2<-GL2[g21+g22+1,]/2
                    }
                    else{
                      PGL2<-GL2[g21+g22+1,]
                    }
                    
                    ########################################
                    ###probability of genotypes given relatedness (P(G1j=g1, G2j=g2|Aj=a, Zj=z)) tabel 1
                    ########################################
                    
                    
                    if(z1==1)
                      P1<-ifelse(g11==g21,g21+(-1)^g21*f[,a11],0)
                    else     #ind1 hap1                    #ind2 hap1
                      P1<-(g11+(-1)^g11*f[,a11]) * (g21+(-1)^g21*f[,a21])
                    
                    if(z2==1)
                      P2<-ifelse(g12==g22,g22+(-1)^g22*f[,a22],0)
                    else     #ind1 hap2                    #ind2 hap2
                      P2<-(g12+(-1)^g12*f[,a12]) * (g22+(-1)^g22*f[,a22])
                   
                    #browser()
                    #mult<-1
                    #mult <- ifelse(geno1==1 ,mult *2 ,mult)
                    #mult <- ifelse(geno2==1 ,mult *2 ,mult)
                    
                    #if(z1+z2 > 0)
                    #  mult <- ifelse(geno1==1 & geno2==1,mult/2 ,mult)
                    
                    mult<-1
                    #mult <- ifelse(g11!=g12 ,mult *2 ,mult)
                    #mult <- ifelse(g21!=g22 ,mult *2 ,mult)
                    
                    #if(z1+z2 > 0)
                    #  mult <- ifelse(g11!=g12 & g21!=g22,mult/2 ,mult)
                    
                    ppart<-Pa*Pz*P1*P2*mult*PGL1*PGL2
              
                    ssum<-ssum+ppart
                    
                    Ek[,2*z1+z2+1]<-Ek[,2*z1+z2+1]+ppart
                  
                    if(pprint)
                      cat(count,"a:",a11,a12,a21,a22,"z:",z1,z2, "G1:",g11,g12, "G2:",g21,g22,"Pa=",Pa,"Pz=",Pz,"sum=",ssum[n],"ppart=",ppart[n],"P1*P2=",P1[n]*P2[n],"\n")
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  logL<-sum(log(ssum))
  PP<-colSums(Ek/rowSums(Ek))/length(f[,1])
  x2<-c(PP[1],PP[2]+PP[3],PP[4])#,logL)
  return(x2)
}

#########################################
#####Calculate the probability parts which are independent of Z and therefore the same for all EM steps. 
#####The output is used as input to NgsAdmixRelateEMoneStep()
#########################################
doProb<-function(Z,a1,a2,geno1,geno2,f,GL1, GL2,n=1,pprint=T){
  ssum<-0
  count<-0
  npop<-length(a1)
  ppart <- matrix(0,ncol=4,nrow=length(geno1))
  
  for(a11 in 1:npop){
    if(a1[a11]==0)
      next
    for(a12 in 1:npop){ 
      if(a1[a12]==0)
        next
      for(a21 in 1:npop){
        if(a2[a21]==0)
          next
        for(a22 in 1:npop){
          if(a2[a22]==0)
            next
          for(z1 in 0:1){ 
            if(z1==1&a11!=a21)
              next
            for(z2 in 0:1){ 
              if(z2==1&a12!=a22)
                next
              for(g1 in 0:1){
                for(g2 in 0:1){
                  
                count<-count+1
                

                ########################################
                ## probablity of ancestral proportions given IBD and Ancestry proportions (P(Aj=a|Zj=z, Q1, Q2))
                ########################################
                Pa<-a1[a11]*a1[a12]*a2[a21]*a2[a22]
                
                if(z1==1)
                  Pa<-Pa/(sum(a1*a2))
                if(z2==1)
                  Pa<-Pa/(sum(a1*a2))
                
                ########################################
                ###probability of data given genotype (P(X|Gj=g1,g2))
                ########################################
                if(g1+g2==1){
                  PGL1<-GL1[g1+g2+1,]/2
                  PGL2<-GL2[g1+g2+1,]/2
                }
                else{
                  PGL1<-GL1[g1+g2+1,]
                  PGL2<-GL2[g1+g2+1,]
                }
                
               
                ########################################
                ###probability of genotypes given relatedness (P(G1j=g1, G2j=g2|Aj=a, Zj=z))
                ########################################
                
                
                
                g11<-ifelse(geno1<1,1,0)
                g12<-ifelse(geno1<2,1,0)
                g21<-ifelse(geno2<1,1,0)
                g22<-ifelse(geno2<2,1,0)
                
                if(z1==1)
                  P1<-ifelse(g11==g21,g21+(-1)^g21*f[,a11],0)
                else     #ind1 hap1                    #ind2 hap1
                  P1<-(g11+(-1)^g11*f[,a11]) * (g21+(-1)^g21*f[,a21])
                
                if(z2==1)
                  P2<-ifelse(g12==g22,g22+(-1)^g22*f[,a22],0)
                else     #ind1 hap2                    #ind2 hap2
                  P2<-(g12+(-1)^g12*f[,a12]) * (g22+(-1)^g22*f[,a22])
                browser()
                mult<-1
                mult <- ifelse(geno1==1 ,mult *2 ,mult)
                mult <- ifelse(geno2==1 ,mult *2 ,mult)
                
                if(z1+z2 > 0)
                  mult <- ifelse(geno1==1 & geno2==1,mult/2 ,mult)
                
                pp<-Pa*P1*P2*mult*PGL1*PGL2
                
                ssum<-ssum+pp 
                
                ppart[,2*z1+z2+1]<-ppart[,2*z1+z2+1]+pp

                if(pprint)
                  cat(count,"a:",a11,a12,a21,a22,"z:",z1,z2, "G:",g1,g2,"Pa=",Pa,"sum=",ssum[n],"ppart=",pp[n],"P1*P2=",P1[n]*P2[n],"\n")
                }
              }
            }
          }
        }
      }
    }
  }

  return(ppart)
}


#########################################
#####Expectaion Maximization ONE STEP takes output (ppart) from doProp() as input 
#########################################
NgsAdmixRelateEMoneStep<-function(par,ppart,n=1,pprint=T){
  Z<-par
  ssum<-0
  count<-0
  npop<-length(ppart)
  Ek <- matrix(0,ncol=4,nrow=length(ppart))
  
  for(z1 in 0:1){ 
    for(z2 in 0:1){ 
          
          count<-count+1
          
          #######################################
          ## probability of IBD given relatedness (P(Z=z|R))
          ########################################
          Pz<-Z[z1+z2+1]/2^(z1!=z2)
          
         # if(Pz==0)
         #   next
          
          pp<-Pz*ppart[,count]
          ssum<-ssum+pp
          
          Ek[,count]<-pp
          
          if(pprint)
            cat(count,"z:",z1,z2, "Pz=",Pz,"sum=",ssum[n],"ppart=",pp[n],"\n")

    }
  }
  logL<-sum(log(ssum))
  PP<-colSums(Ek/rowSums(Ek))/length(ppart)
  x2<-c(PP[1],PP[2]+PP[3],PP[4])#,logL)
  return(x2)
}

#########################################
#####Expectaion Maximization 
#########################################

NgsAdmixRelateEM<-function(initZ,a1,a2,geno1,geno2,f,GL1,GL2,maxit,tol){
  
  par<-c(initZ,NA)
  flag<-0
  ppart<-doProb(initZ,a1,a2,geno[,1],geno[,2],f,like1,like2,pprint=F)
  
  for(i in 1:maxit){
    newPar<-NgsAdmixRelateEMoneStep(par[1:3],ppart,pprint=F)
    cat("Iteration:",i-1,"LogLike = ",newPar[4], "Z = ",par[1],par[2],par[3],"\n")
    # Stop iteration if the difference between the current and new estimates is less than a tolerance level
    
    if(all(abs(par[1:3] - newPar[1:3]) < tol)){
      flag <- 1 
      cat("Congratulations the EM algorithm has converged! \n")
      return(par)
      break
    }
    
    # Otherwise continue iteration
    par <- newPar
    
  }
  if(!flag){
    warning("Didn't converge\n")
    return(newPar)
  } 
  
  # list(Z, logL)
}

#########################################
#####OLD Expectaion Maximization based on NgsAdmixRelateEMoneStepOld
#########################################
NgsAdmixRelateEMOld<-function(initZ,a1,a2,f,GL1,GL2,maxit,tol){
  
  par<-c(initZ,NA)
  flag<-0
  
  for(i in 1:maxit){
    newPar<-NgsAdmixRelateEMoneStepOld(par[1:3],a1,a2,f,GL1,GL2,pprint=F)
    cat("Iteration:",i-1,"LogLike = ",newPar[4], "Z = ",par[1],par[2],par[3],"\n")
    # Stop iteration if the difference between the current and new estimates is less than a tolerance level
    
    if(all(abs(par[1:3] - newPar[1:3]) < tol)){
      flag <- 1 
      cat("Congratulations the EM algorithm has converged! \n")
      return(par)
      break
    }
    
    # Otherwise continue iteration
    par <- newPar
    
  }
  if(!flag){
    warning("Didn't converge\n")
    return(newPar)
  } 
  
  # list(Z, logL)
}

#########################################
#####Expectaion Maximization based on SQUAREM
#########################################

NgsAdmixRelateSquareEM<-function(initZ,a1,a2,geno1,geno2,f,GL1,GL2,maxit,tol,pprint){
  ppart<-doProb(initZ,a1,a2,geno1,geno2,f,GL1,GL2,pprint=pprint)
  newPar<-squarem(par=initZ,ppart=ppart,pprint=pprint,fixptfn=NgsAdmixRelateEMoneStep,control=list(maxiter=maxit,tol=tol))
  return(newPar$par)
}




###############################################
#####3 populationer, siblings K=(0.25,0.5,0.25)
##############################################

M<-100000 # No. of diallelic loci
f1<-runif(M) #randomly sample an allele frequency from a uniform distribution between 0 and 1
f2<-runif(M)
f3<-runif(M)
f<-cbind(f1,f2,f3)
#f[f>-1]<-0.2

#########################################
#####Simulate genotypes
#########################################
k2=c(0.25,0,0) ### 25%:  IBD 2 fra population 1
k1=c(0.5,0,0) ### 50% : IBD 1 fra population 1.
k0=c(0.25,0,0)

a1<-k2+k1+k0# (Ancestry proportions) Q individ 1. k1/2, da den ene halvdel er IBD 1 for allele 1 og den anden halvdel er IBD 1 for allele 2 (a2). output = (1,0,0), da vi kun ha en population. 
a2<-k2+k1+k0# (Ancestry proportions) Q individ 2. c(0.5,0,0) forstår jeg ikke... 0,5, fordi frekvensen skal fordeles ligeligt på allele 1 og 2 ????
if(sum(a1)!=1 | sum(a2)!=1)
  print("you fucked up")

geno<-simGeno(k1,k2,a1,a2,f) #geno output: 0,1,2
trueZ<-c(1-sum(k1)-sum(k2),sum(k1),sum(k2))# Relatedness coefficients


#########################################
#####Simulate Genotype likelihoods 
#########################################

depth <- 25 #mean depth
error <- 0.01
like1<-getLikes(geno[,1], depth, error) #genotype likelihoods for individual 1
like2<-getLikes(geno[,2], depth, error)


#########################################
#####Maximum likelihood 
#########################################
NgsAdmixRelateML(initZ,a1,a2,geno[,1],geno[,2],f,like1,like2)

#########################################
#####Expectaion Maximization ONE STEP
#########################################
#make one step in em based
initZ<-c(0.2,0.4,0.4)

#old version which calculate all probabilities in every loop
NgsAdmixRelateEMoneStepOld(initZ,a1,a2,f,like1,like2)

#doProp calculate the probabiility parts which are independent of Z and therefore the same for all EM steps
ppart<-doProb(initZ,a1,a2,geno[,1],geno[,2],f,like1,like2,pprint=F)
NgsAdmixRelateEMoneStep(initZ,ppart,n=1)


############################################
##### Expectaion Maximization
###########################################
M<-100000 # No. of diallelic loci
f1<-runif(M) #0.05 og 0.95#randomly sample an allele frequency from a uniform distribution between 0 and 1
f2<-runif(M)
f3<-runif(M)
f<-cbind(f1,f2,f3)
depth <- 30 #mean depth
error <- 0.05
initZ<- c(0.2,0.4,0.4)#Initial values for the parameters to be optimized #ALGO virker ikke, hvis initZ=(0,0,0)
maxit<-100
tol<-1e-3

## siblings one population - FIKS med a....
k2=c(0.25,0,0) ### 25%:  IBD 2 fra population 1
k1=c(0.5,0,0) ### 50% : IBD 1 fra population 1.
k0<-c(0.25,0,0)

## siblings 2 populations 
k2<-c(0.125,0.125,0) ### 25%:  IBD 2 fra population 1
k1<-c(0.25,0.25,0) ### 50% : IBD 1 fra population 1.
k0<-c(0.125,0.125,0)

## siblings 3 populations 
k2<-c(0.1,0.1,0.05) ### 25%:  IBD 2 fra population 1
k1<-c(0.1,0.2,0.2) ### 50% : IBD 1 fra population 1.
k0<-c(0.05,0.2,0)

k2<-c(0,0,0) ### 25%:  IBD 2 fra population 1
k1<-c(0,0,0) ### 50% : IBD 1 fra population 1.
k0<-c(1,0,0)

a1<-c(0.2,0.2,0.6)#k2+k1+k0# (Ancestry proportions) Q individ 1. 
a2<-c(0.3,0.5,0.2)#k2+k1+k0# (Ancestry proportions) Q individ 2.
a1<-c(1,0,0)#k2+k1+k0# (Ancestry proportions) Q individ 1. 
a2<-c(1,0,0)#k2+k1+k0# (Ancestry proportions) Q individ 2.

geno<-simGeno(k1,k2,a1,a2,f) #geno output: 0,1,2
like1<-getLikes(geno[,1], depth, error) #genotype likelihoods for individual 1
like2<-getLikes(geno[,2], depth, error)


NgsAdmixRelateSquareEM(initZ,a1,a2,geno[,1],geno[,2],f,like1,like2,maxit,tol,pprint=F)
NgsAdmixRelateEM(initZ,a1,a2,geno[,1],geno[,2],f,like1,like2,maxit,tol)
NgsAdmixRelateEMOld(initZ,a1,a2,f,like1,like2,maxit,tol)

